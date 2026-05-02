extends Node3D

# ──────────────────────────────────────────────────────────────────────
# REFERENCIAS A NODOS
# ──────────────────────────────────────────────────────────────────────
@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: MainMenuUI = $MainMenuUI
@onready var multiplayer_chat: MultiplayerChatUI = $MultiplayerChatUI
@onready var crosshair: CanvasLayer = $CanvasLayer

@export var player_scene: PackedScene

# ──────────────────────────────────────────────────────────────────────
# ESCENAS PRECARGADAS
# ──────────────────────────────────────────────────────────────────────
const HUD_SCENE              = preload("res://scenes/ui/HUD.tscn")
const CHARACTER_SELECT_SCENE = preload("res://scenes/ui/character_select.tscn")
const GAME_MODE_SCENE        = preload("res://scenes/ui/game_mode_select.tscn")

# ──────────────────────────────────────────────────────────────────────
# ESTADO INTERNO
# ──────────────────────────────────────────────────────────────────────
var _char_select: CharacterSelectUI = null
var _game_mode_select: GameModeSelectUI = null
var _hud: CanvasLayer = null

var _pending_nickname: String = ""
var _pending_character: String = ""

var chat_visible: bool = false


# ──────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if Network.is_dedicated_server():
		_setup_dedicated_server_mode()
		return

	multiplayer_chat.hide()
	main_menu.show_menu()
	multiplayer_chat.set_process_input(true)

	main_menu.open_character_select.connect(_on_open_character_select)
	main_menu.quit_pressed.connect(_on_quit_pressed)

	if multiplayer_chat:
		multiplayer_chat.message_sent.connect(_on_chat_message_sent)

	Network.server_disconnected.connect(_on_server_disconnected)

	if Network.has_signal("connection_failed_with_reason"):
		Network.connection_failed_with_reason.connect(_on_connection_failed_with_reason)

	# FIX: TODOS conectan estas señales, no solo el servidor.
	# El host necesita ver al cliente, el cliente necesita ver al host.
	# Solo _remove_player sigue siendo exclusivo del servidor porque
	# él es quien destruye el nodo autoritativamente.
	Network.player_connected.connect(_on_player_connected)
	
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_remove_player)


# CAMBIO: función nueva para configurar el modo dedicated server.
# Oculta toda la UI ya que en este modo solo se usa para la lógica del juego.
func _setup_dedicated_server_mode() -> void:
	if main_menu: main_menu.hide()
	if multiplayer_chat: multiplayer_chat.hide()
	if crosshair: crosshair.hide()

	# El server SÍ necesita escuchar la conexión de jugadores para spawnearlos
	Network.player_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_remove_player)


# ──────────────────────────────────────────────────────────────────────
# DESCONEXIÓN / CLEANUP
# ──────────────────────────────────────────────────────────────────────
func _on_server_disconnected() -> void:
	# Limpieza completa cuando se cae el servidor o nos desconectan
	if _hud:
		_hud.queue_free()
		_hud = null

	for child in players_container.get_children():
		child.queue_free()

	chat_visible = false
	multiplayer_chat.hide()
	crosshair.hide()
	main_menu.show_menu()


# CAMBIO: handler nuevo para mostrar errores de conexión legibles al usuario
func _on_connection_failed_with_reason(reason: String) -> void:
	push_warning("[Level] Conexión fallida: %s" % reason)
	# Si tu MainMenuUI tiene un método para mostrar errores, úsalo:
	if main_menu and main_menu.has_method("show_error"):
		main_menu.show_error(reason)
	# Si no, al menos vuelve al menú para que el usuario pueda reintentar
	main_menu.show_menu()


# ──────────────────────────────────────────────────────────────────────
# SPAWNEO DE JUGADORES
# ──────────────────────────────────────────────────────────────────────
func _on_player_connected(peer_id: int, player_info: Dictionary) -> void:
	_add_player(peer_id, player_info)

func _add_player(id: int, player_info: Dictionary) -> void:
	Network.remote_print("[Level] _add_player | id=%d | soy=%d | es_server=%s | nodo_existe=%s" % [
		id, multiplayer.get_unique_id(), multiplayer.is_server(),
		players_container.has_node(str(id))
	])
	if Network.is_dedicated_server() and id == 1:
		return

	var player: Node = null

	if players_container.has_node(str(id)):
		player = players_container.get_node(str(id))
	else:
		player = player_scene.instantiate()
		player.name = str(id)
		player.position = get_spawn_point()
		players_container.add_child(player, true)

	if player == null:
		push_error("[Level] No se pudo obtener nodo del jugador %d" % id)
		return

	# Nickname
	var nick: String = player_info.get("nick", "Player_%d" % id)
	if player.nickname:
		player.nickname.text = nick

	# CAMBIO: cada peer carga el personaje localmente con el character_id
	# que ya llegó en player_info. No se necesita RPC adicional.
	# Esto funciona porque player_info ya contiene "character" desde
	# el registro en Network.gd y está disponible en TODOS los peers.
	var character_id: String = player_info.get("character", "amy")
	print("[Level] Cargando personaje '%s' para nodo '%s'" % [character_id, str(id)])
	player.set_character_by_id_local(character_id)

	# HUD
	if id == multiplayer.get_unique_id():
		if _hud == null:
			_spawn_hud(_pending_nickname)
		call_deferred("_connect_player_to_hud", player)


# CAMBIO: función separada para conectar el HUD de forma diferida
func _connect_player_to_hud(player: Node) -> void:
	if not _hud:
		return
	var ab = _hud.get_action_buttons()
	if ab:
		ab.set_player(player)

func get_spawn_point() -> Vector3:
	# Spawn en círculo alrededor del centro del mapa
	var spawn_point := Vector2.from_angle(randf() * 2 * PI) * 10
	return Vector3(spawn_point.x, 0, spawn_point.y)


func _remove_player(id: int) -> void:
	# Solo el servidor destruye jugadores autoritativamente
	if not multiplayer.is_server():
		return
	if not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()


# ──────────────────────────────────────────────────────────────────────
# FLUJO: Menú → Selector de personaje
# ──────────────────────────────────────────────────────────────────────
func _on_open_character_select(nickname: String, address: String, is_host: bool) -> void:
	main_menu.hide_menu()

	if _char_select == null:
		_char_select = CHARACTER_SELECT_SCENE.instantiate()
		add_child(_char_select)
		_char_select.host_confirmed.connect(_on_host_confirmed)
		_char_select.join_confirmed.connect(_on_join_confirmed)

	_char_select.setup(nickname, address, is_host)
	_char_select.show()


func show_main_menu_from_character_select() -> void:
	if _char_select:
		_char_select.hide()
	main_menu.show_menu()


# ──────────────────────────────────────────────────────────────────────
# FLUJO: Selector de personaje → Selector de modo (solo host)
# ──────────────────────────────────────────────────────────────────────
func _on_host_confirmed(nickname: String, character: String) -> void:
	if _char_select:
		_char_select.hide()

	# Guardar datos hasta que el host elija el modo
	_pending_nickname = nickname
	_pending_character = character

	# Abrir selector de modo de juego
	if _game_mode_select == null:
		_game_mode_select = GAME_MODE_SCENE.instantiate()
		add_child(_game_mode_select)
		_game_mode_select.mode_confirmed.connect(_on_mode_confirmed)

	_game_mode_select.show()


# ──────────────────────────────────────────────────────────────────────
# FLUJO: Selector de modo → Juego
# ──────────────────────────────────────────────────────────────────────
func _on_mode_confirmed(mode_id: String) -> void:
	if _game_mode_select:
		_game_mode_select.hide()

	crosshair.show()
	_spawn_hud(_pending_nickname)

	# CAMBIO: capturar el código de error de start_host para feedback claro.
	# Si falla, el usuario vuelve al menú con un mensaje (vía la señal
	# connection_failed_with_reason que ya conectamos arriba).
	var result := Network.start_host(_pending_nickname, _pending_character)
	if result != OK:
		push_error("[Level] No se pudo iniciar el host")
		_on_server_disconnected()
		return

	# Guardar modo para usarlo en el juego
	GameManager.selected_mode = mode_id


# ──────────────────────────────────────────────────────────────────────
# FLUJO: Join → directo al juego (sin selector de modo)
# ──────────────────────────────────────────────────────────────────────
func _on_join_confirmed(nickname: String, character: String, address: String) -> void:
	if _char_select:
		_char_select.hide()

	crosshair.show()

	var result := Network.join_game(nickname, character, address)
	if result != OK:
		push_error("[Level] No se pudo iniciar la conexión")
		_on_server_disconnected()
		return

	# CAMBIO: spawn del HUD diferido para que la escena esté lista
	call_deferred("_spawn_hud", nickname)


# ──────────────────────────────────────────────────────────────────────
# HUD
# ──────────────────────────────────────────────────────────────────────
func _spawn_hud(nickname: String) -> void:
	if _hud != null:
		return
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.set_nickname(nickname)


# ──────────────────────────────────────────────────────────────────────
# UTILIDADES PÚBLICAS
# ──────────────────────────────────────────────────────────────────────
func _on_quit_pressed() -> void:
	# CAMBIO: desconexión limpia antes de cerrar (si está conectado)
	if Network.is_connected_to_game():
		Network.disconnect_from_game()
	get_tree().quit()


func get_local_player():
	var local_player_id := multiplayer.get_unique_id()
	if players_container.has_node(str(local_player_id)):
		return players_container.get_node(str(local_player_id))
	return null


# ──────────────────────────────────────────────────────────────────────
# CHAT
# ──────────────────────────────────────────────────────────────────────
func toggle_chat() -> void:
	if main_menu.is_menu_visible():
		return
	multiplayer_chat.toggle_chat()
	chat_visible = multiplayer_chat.is_chat_visible()


func is_chat_visible() -> bool:
	return multiplayer_chat.is_chat_visible()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif chat_visible and multiplayer_chat.message.has_focus():
		if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
			multiplayer_chat._on_send_pressed()
			get_viewport().set_input_as_handled()


func _on_chat_message_sent(message_text: String) -> void:
	var trimmed_message := message_text.strip_edges()
	if trimmed_message.is_empty():
		return

	# CAMBIO: validar que el jugador esté registrado antes de enviar el mensaje.
	# Antes podía crashear si players[unique_id] no existía aún.
	var my_id := multiplayer.get_unique_id()
	if not Network.players.has(my_id):
		push_warning("[Level] Intento de chat sin estar registrado")
		return

	var nick: String = Network.players[my_id].get("nick", "Player")
	rpc("msg_rpc", nick, trimmed_message)


@rpc("any_peer", "call_local")
func msg_rpc(nick: String, msg: String) -> void:
	# CAMBIO: validación de longitud para evitar spam de mensajes gigantes
	if msg.length() > 200:
		msg = msg.substr(0, 200) + "..."
	multiplayer_chat.add_message(nick, msg)


# ──────────────────────────────────────────────────────────────────────
# DATA DE PERSONAJES
# ──────────────────────────────────────────────────────────────────────
func _load_character_data(character_id: String) -> CharacterData:
	var paths := {
		"amy":       "res://assets/characters/team_a/Amy/amy.tres",
		"michelle":  "res://assets/characters/team_a/Michelle/michelle.tres",
		"ortiz":     "res://assets/characters/team_a/Ortiz/ortiz.tres",
		"big_vegas": "res://assets/characters/team_b/Big Vegas/big_vegas.tres",
		"kaya":      "res://assets/characters/team_a/Kaya/kaya.tres",
		"mousey":    "res://assets/characters/team_b/Mousey/mousey.tres"
	}
	if character_id in paths:
		return load(paths[character_id])
	push_warning("[Level] Personaje desconocido: %s" % character_id)
	return null


# ──────────────────────────────────────────────────────────────────────
# RPCs DE MUERTE / RESPAWN
# Estos los llama el servidor para sincronizar muerte/respawn entre clientes.
# ──────────────────────────────────────────────────────────────────────
@rpc("authority", "call_local", "reliable")
func broadcast_death(player_name: String) -> void:
	var player = players_container.get_node_or_null(player_name)
	if player:
		player._play_death_local()


@rpc("authority", "call_local", "reliable")
func broadcast_respawn(player_name: String) -> void:
	var player = players_container.get_node_or_null(player_name)
	if player:
		player.do_respawn()
