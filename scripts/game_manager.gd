extends Node

# ──────────────────────────────────────────────────────────────────────
# GAME MANAGER (autoload)
# Estado autoritativo de la partida: equipos, scores, modo, timer.
# Solo el servidor modifica el estado; los clientes lo reciben replicado.
# ──────────────────────────────────────────────────────────────────────

# ──── ENUMS ────────────────────────────────────────────────────────────
enum Team { NONE, TEAM_A, TEAM_B }
enum MatchState { WAITING, IN_PROGRESS, ENDED }

# ──── CONSTANTES ───────────────────────────────────────────────────────
const TEAM_DEATHMATCH_TARGET_KILLS: int = 20
const TIME_BATTLE_DURATION: float = 60.0   # 1 minuto para testing. Cambia a 600.0 para release.
const COUNTDOWN_DURATION: float = 3.0       # cuenta regresiva al iniciar partida
const MAX_TEAM_DIFFERENCE: int = 1          # diferencia máxima entre equipos
const MAX_PLAYERS_PER_TEAM: int = 2         # 2v2 máximo

# Buff para jugador en desventaja (1 vs 2)
const UNDERDOG_HEALTH_MULTIPLIER: float = 2.0
const UNDERDOG_DAMAGE_MULTIPLIER: float = 2.0

# ──── ESTADO ──────────────────────────────────────────────────────────
var selected_mode: String = "team_deathmatch"
var match_state: MatchState = MatchState.WAITING

var team_a_score: int = 0
var team_b_score: int = 0
var team_a_players: Array[int] = []   # peer_ids
var team_b_players: Array[int] = []

var time_remaining: float = TIME_BATTLE_DURATION
var winning_team: Team = Team.NONE

# ──── SEÑALES ──────────────────────────────────────────────────────────
signal score_updated(team_a: int, team_b: int)
signal time_updated(remaining: float)
signal match_started
signal match_ended(winning_team: int)
signal countdown_tick(seconds_left: int)


# ──────────────────────────────────────────────────────────────────────
# UTILIDADES DE EQUIPO
# El equipo se determina por el path del CharacterData (team_a o team_b).
# ──────────────────────────────────────────────────────────────────────
func get_team_from_character(character_id: String) -> Team:
	# Mapeo basado en las carpetas del proyecto
	var team_a_chars := ["amy", "michelle", "ortiz", "kaya"]
	var team_b_chars := ["mousey", "big_vegas"]

	if character_id in team_a_chars:
		return Team.TEAM_A
	elif character_id in team_b_chars:
		return Team.TEAM_B
	push_warning("[GameManager] Personaje sin equipo asignado: %s" % character_id)
	return Team.NONE


func get_team_name(team: Team) -> String:
	match team:
		Team.TEAM_A: return "Equipo Celeste"
		Team.TEAM_B: return "Equipo Rojo"
		_: return "Sin equipo"


func get_team_color(team: Team) -> Color:
	match team:
		Team.TEAM_A: return Color(0.4, 0.7, 1.0)   # celeste
		Team.TEAM_B: return Color(1.0, 0.3, 0.3)   # rojo
		_: return Color.WHITE


# ──────────────────────────────────────────────────────────────────────
# REGISTRO DE JUGADORES EN EQUIPOS
# Llamado desde Level.gd cuando un jugador entra a la partida.
# ──────────────────────────────────────────────────────────────────────
func register_player_team(peer_id: int, character_id: String) -> void:
	var team := get_team_from_character(character_id)
	# Limpiar de equipos previos por si reconecta
	team_a_players.erase(peer_id)
	team_b_players.erase(peer_id)

	match team:
		Team.TEAM_A:
			team_a_players.append(peer_id)
		Team.TEAM_B:
			team_b_players.append(peer_id)
	print("[GameManager] Jugador %d en %s | A=%d B=%d" % [
		peer_id, get_team_name(team), team_a_players.size(), team_b_players.size()
	])


func unregister_player(peer_id: int) -> void:
	team_a_players.erase(peer_id)
	team_b_players.erase(peer_id)


func get_player_team(peer_id: int) -> Team:
	if peer_id in team_a_players:
		return Team.TEAM_A
	elif peer_id in team_b_players:
		return Team.TEAM_B
	return Team.NONE


# Validación de bando al confirmar selección
# Llamado desde CharacterSelect antes de unirse al juego
func can_join_team(target_team: Team) -> bool:
	var a_count := team_a_players.size()
	var b_count := team_b_players.size()

	# Verificar capacidad máxima
	if target_team == Team.TEAM_A and a_count >= MAX_PLAYERS_PER_TEAM:
		return false
	if target_team == Team.TEAM_B and b_count >= MAX_PLAYERS_PER_TEAM:
		return false

	# Verificar diferencia máxima si te unes a este equipo
	if target_team == Team.TEAM_A:
		# Si me uno a A, A tendría a_count+1
		# La diferencia con B sería (a_count+1) - b_count
		if (a_count + 1) - b_count > MAX_TEAM_DIFFERENCE:
			return false
	elif target_team == Team.TEAM_B:
		if (b_count + 1) - a_count > MAX_TEAM_DIFFERENCE:
			return false

	return true


# ──────────────────────────────────────────────────────────────────────
# BUFF DE DESVENTAJA (UNDERDOG)
# Llamado al inicio de la partida. Solo se calcula una vez.
# ──────────────────────────────────────────────────────────────────────
func should_apply_underdog_buff(peer_id: int) -> bool:
	# Aplica solo si tu equipo tiene 1 jugador y el otro tiene más
	var my_team := get_player_team(peer_id)
	if my_team == Team.NONE:
		return false

	if my_team == Team.TEAM_A:
		return team_a_players.size() == 1 and team_b_players.size() > 1
	elif my_team == Team.TEAM_B:
		return team_b_players.size() == 1 and team_a_players.size() > 1
	return false


# ──────────────────────────────────────────────────────────────────────
# CICLO DE PARTIDA
# ──────────────────────────────────────────────────────────────────────

# El servidor llama esto para iniciar la cuenta regresiva
func server_start_match() -> void:
	if not multiplayer.is_server():
		return

	team_a_score = 0
	team_b_score = 0
	time_remaining = TIME_BATTLE_DURATION
	winning_team = Team.NONE
	match_state = MatchState.WAITING

	# Sincronizar estado inicial a todos los clientes
	_sync_match_start.rpc(selected_mode, team_a_players, team_b_players)

	# Cuenta regresiva
	for i in range(int(COUNTDOWN_DURATION), 0, -1):
		_sync_countdown.rpc(i)
		await get_tree().create_timer(1.0).timeout

	# Iniciar partida
	match_state = MatchState.IN_PROGRESS
	_sync_match_started.rpc()

	# Si es modo time_battle, arrancar el timer
	if selected_mode == "time_battle":
		_run_time_battle_loop()


func _run_time_battle_loop() -> void:
	while match_state == MatchState.IN_PROGRESS and time_remaining > 0:
		await get_tree().create_timer(1.0).timeout
		if match_state != MatchState.IN_PROGRESS:
			return
		time_remaining -= 1.0
		_sync_time.rpc(time_remaining)

	if match_state == MatchState.IN_PROGRESS:
		# Se acabó el tiempo: gana el equipo con más kills
		_end_match_by_time()


func _end_match_by_time() -> void:
	if not multiplayer.is_server():
		return

	var winner: Team
	if team_a_score > team_b_score:
		winner = Team.TEAM_A
	elif team_b_score > team_a_score:
		winner = Team.TEAM_B
	else:
		# Empate: gana cualquiera o ninguno. Pongamos NONE como empate.
		winner = Team.NONE

	server_end_match(winner)


# Reportar una muerte al servidor.
# Llamado desde Player.gd cuando alguien muere.
func report_kill(victim_peer_id: int, killer_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if match_state != MatchState.IN_PROGRESS:
		return

	var killer_team := get_player_team(killer_peer_id)
	if killer_team == Team.NONE:
		return  # kill sin equipo válido (suicidio, caída, etc.)

	# No contar team kills
	var victim_team := get_player_team(victim_peer_id)
	if victim_team == killer_team:
		return

	if killer_team == Team.TEAM_A:
		team_a_score += 1
	elif killer_team == Team.TEAM_B:
		team_b_score += 1

	_sync_score.rpc(team_a_score, team_b_score)

	# Verificar condición de victoria por kills (solo team_deathmatch)
	if selected_mode == "team_deathmatch":
		if team_a_score >= TEAM_DEATHMATCH_TARGET_KILLS:
			server_end_match(Team.TEAM_A)
		elif team_b_score >= TEAM_DEATHMATCH_TARGET_KILLS:
			server_end_match(Team.TEAM_B)


func server_end_match(winner: Team) -> void:
	if not multiplayer.is_server():
		return
	if match_state == MatchState.ENDED:
		return

	match_state = MatchState.ENDED
	winning_team = winner
	_sync_match_end.rpc(winner)
	print("[GameManager] Partida terminada. Ganador: %s" % get_team_name(winner))


# ──────────────────────────────────────────────────────────────────────
# RPCs DE SINCRONIZACIÓN (servidor → clientes)
# ──────────────────────────────────────────────────────────────────────

@rpc("authority", "reliable", "call_local")
func _sync_match_start(mode: String, players_a: Array, players_b: Array) -> void:
	selected_mode = mode
	team_a_players.clear()
	team_b_players.clear()
	for p in players_a:
		team_a_players.append(p)
	for p in players_b:
		team_b_players.append(p)
	team_a_score = 0
	team_b_score = 0
	time_remaining = TIME_BATTLE_DURATION
	score_updated.emit(0, 0)


@rpc("authority", "reliable", "call_local")
func _sync_countdown(seconds_left: int) -> void:
	countdown_tick.emit(seconds_left)


@rpc("authority", "reliable", "call_local")
func _sync_match_started() -> void:
	match_state = MatchState.IN_PROGRESS
	match_started.emit()


@rpc("authority", "unreliable_ordered", "call_local")
func _sync_score(score_a: int, score_b: int) -> void:
	team_a_score = score_a
	team_b_score = score_b
	score_updated.emit(score_a, score_b)


@rpc("authority", "unreliable_ordered", "call_local")
func _sync_time(remaining: float) -> void:
	time_remaining = remaining
	time_updated.emit(remaining)


@rpc("authority", "reliable", "call_local")
func _sync_match_end(winner: Team) -> void:
	match_state = MatchState.ENDED
	winning_team = winner
	match_ended.emit(winner)
