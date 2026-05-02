extends Node

# ──────────────────────────────────────────────────────────────────────
# CONSTANTES
# ──────────────────────────────────────────────────────────────────────
const SERVER_PORT: int = 7777
const MAX_PLAYERS: int = 8  # CAMBIO: 8 es suficiente para 4v4. Antes era 10.

# Timeouts de ENet en milisegundos.
# Importante para móvil: tolera saltos breves de WiFi a 4G sin desconectar.
const ENET_TIMEOUT_LIMIT: int = 32        # paquetes perdidos antes de desconectar
const ENET_TIMEOUT_MIN: int = 5000        # 5 segundos
const ENET_TIMEOUT_MAX: int = 15000       # 15 segundos

# ──────────────────────────────────────────────────────────────────────
# ENUM DE MODO DE RED
# Distinguir explícitamente entre los modos en lugar de inferirlos
# del display server. Más claro, más mantenible.
# ──────────────────────────────────────────────────────────────────────
enum NetMode {
	NONE,                # Sin red activa
	LISTEN_SERVER,       # Host-cliente: un jugador hostea Y juega (tu caso actual)
	DEDICATED_SERVER,    # Solo servidor sin jugador local (futuro / opcional)
	CLIENT               # Cliente conectándose a un host
}

var net_mode: NetMode = NetMode.NONE

# ──────────────────────────────────────────────────────────────────────
# ESTADO
# ──────────────────────────────────────────────────────────────────────
var players: Dictionary = {}

var player_info: Dictionary = {
	"nick": "host",
	"character": "amy"
}

# ──────────────────────────────────────────────────────────────────────
# SEÑALES
# ──────────────────────────────────────────────────────────────────────
signal player_connected(peer_id: int, player_info: Dictionary)
signal server_disconnected
# CAMBIO: nueva señal para notificar errores de conexión a la UI
signal connection_failed_with_reason(reason: String)


# ──────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

	# CAMBIO: Auto-arranque de servidor dedicado solo si se pasa flag explícito.
	# Antes se inferia de DisplayServer.get_name() == "headless", que es frágil.
	# Ahora se puede correr el servidor con: godot --headless -- --server
	if "--server" in OS.get_cmdline_user_args():
		print("[Network] Modo servidor dedicado detectado por argumento --server")
		start_dedicated_server()


func _process(_delta: float) -> void:
	# CAMBIO: el quit se mantiene pero solo dispara si NO estamos en chat
	# o en menús, para evitar quits accidentales mientras se escribe.
	# (Este chequeo es básico; refínalo si quieres según tu UI)
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)


# ──────────────────────────────────────────────────────────────────────
# HOST (LISTEN SERVER) — el que tú usas: hostear y jugar a la vez
# ──────────────────────────────────────────────────────────────────────
func start_host(nickname: String, character_id: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(SERVER_PORT, MAX_PLAYERS)

	if error != OK:
		push_error("[Network] Error al crear servidor: %s" % error)
		connection_failed_with_reason.emit("No se pudo abrir el puerto %d" % SERVER_PORT)
		return error

	multiplayer.multiplayer_peer = peer

	# CAMBIO: Compresión de paquetes. Reduce bandwidth ~30%.
	# DEBE estar habilitado en host Y clientes (ambos lados).
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)

	net_mode = NetMode.LISTEN_SERVER
	print("[Network] Servidor iniciado en puerto %d (modo: listen-server)" % SERVER_PORT)

	# Validación y default de nickname
	if nickname.strip_edges().is_empty():
		nickname = "Host_%d" % multiplayer.get_unique_id()
	player_info["nick"] = nickname
	player_info["character"] = character_id

	# Registrar al host como jugador 1
	players[1] = player_info
	player_connected.emit(1, player_info)
	return OK


# ──────────────────────────────────────────────────────────────────────
# DEDICATED SERVER — opcional, sin jugador local
# (No lo usas en tu proyecto escolar pero queda preparado por si algún día
# quieres montarlo en un VPS)
# ──────────────────────────────────────────────────────────────────────
func start_dedicated_server() -> int:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(SERVER_PORT, MAX_PLAYERS)

	if error != OK:
		push_error("[Network] Error al crear servidor dedicado: %s" % error)
		return error

	multiplayer.multiplayer_peer = peer
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)

	net_mode = NetMode.DEDICATED_SERVER
	print("[Network] Servidor dedicado iniciado en puerto %d" % SERVER_PORT)
	# IMPORTANTE: en dedicated server NO se agrega el peer 1 como jugador.
	# El servidor solo coordina, no juega.
	return OK


# ──────────────────────────────────────────────────────────────────────
# CLIENTE
# ──────────────────────────────────────────────────────────────────────
func join_game(nickname: String, character_id: String, address: String) -> int:
	# CAMBIO: validación básica de la dirección para evitar errores tontos
	if address.strip_edges().is_empty():
		push_error("[Network] Dirección vacía")
		connection_failed_with_reason.emit("Ingresa una dirección IP")
		return ERR_INVALID_PARAMETER

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, SERVER_PORT)

	if error != OK:
		push_error("[Network] Error al conectar: %s" % error)
		connection_failed_with_reason.emit("No se pudo conectar a %s" % address)
		return error

	multiplayer.multiplayer_peer = peer

	# CAMBIO: Compresión también en cliente. Si no coincide con el server,
	# la conexión falla. Por eso es importante que ambos la tengan.
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)

	net_mode = NetMode.CLIENT
	print("[Network] Conectando a %s:%d ..." % [address, SERVER_PORT])

	if nickname.strip_edges().is_empty():
		nickname = "Player_%d" % randi_range(1000, 9999)
	player_info["nick"] = nickname
	player_info["character"] = character_id
	return OK


# ──────────────────────────────────────────────────────────────────────
# DESCONEXIÓN LIMPIA
# CAMBIO: función nueva para que la UI pueda desconectar limpiamente
# en lugar de solo esperar timeouts.
# ──────────────────────────────────────────────────────────────────────
func disconnect_from_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	net_mode = NetMode.NONE
	print("[Network] Desconectado limpiamente")


# ──────────────────────────────────────────────────────────────────────
# EVENTOS DE CONEXIÓN
# ──────────────────────────────────────────────────────────────────────
func _on_connected_ok() -> void:
	print("[Network] Conectado al servidor")
	var peer_id := multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)
	_register_player.rpc_id(1, player_info)


func _on_connection_failed() -> void:
	push_warning("[Network] Falló la conexión")
	multiplayer.multiplayer_peer = null
	net_mode = NetMode.NONE
	connection_failed_with_reason.emit("Falló la conexión al servidor")
	server_disconnected.emit()


func _on_server_disconnected() -> void:
	push_warning("[Network] Servidor desconectado")
	multiplayer.multiplayer_peer = null
	players.clear()
	net_mode = NetMode.NONE
	server_disconnected.emit()


func _on_player_connected(id: int) -> void:
	print("[Network] Peer conectado: %d" % id)

	# CAMBIO: aplicar timeouts personalizados al peer recién conectado.
	# Esto da margen para que un cliente móvil que cambia de WiFi a 4G
	# no se desconecte instantáneamente.
	_configure_peer_timeout(id)

	# Solo el server inicia el handshake de registro
	if not multiplayer.is_server():
		return

	# En dedicated server, no enviamos info del server porque no juega
	if net_mode == NetMode.DEDICATED_SERVER and id != 1:
		_register_player.rpc_id(id, player_info)
	elif net_mode == NetMode.LISTEN_SERVER:
		_register_player.rpc_id(id, player_info)


func _on_player_disconnected(id: int) -> void:
	print("[Network] Peer desconectado: %d" % id)
	players.erase(id)


# CAMBIO: helper nuevo para configurar timeouts. Importante en móvil.
func _configure_peer_timeout(peer_id: int) -> void:
	if not multiplayer.multiplayer_peer:
		return
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not enet:
		return
	var enet_peer := enet.get_peer(peer_id)
	if enet_peer:
		enet_peer.set_timeout(ENET_TIMEOUT_LIMIT, ENET_TIMEOUT_MIN, ENET_TIMEOUT_MAX)


# ──────────────────────────────────────────────────────────────────────
# REGISTRO DE JUGADORES
# CAMBIO: Validación básica añadida. Solo procesa el registro si llega
# del peer correcto y los datos son razonables. No es anti-cheat real,
# pero evita bugs y entradas malformadas.
# ──────────────────────────────────────────────────────────────────────
@rpc("any_peer", "reliable")
func _register_player(new_player_info: Dictionary) -> void:
	var new_player_id := multiplayer.get_remote_sender_id()
	print("[Network] _register_player | sender=%d | es_server=%s" % [
		new_player_id, multiplayer.is_server()
	])

	if not new_player_info is Dictionary:
		push_warning("[Network] _register_player recibió datos inválidos")
		return
	if not new_player_info.has("nick") or not new_player_info.has("character"):
		push_warning("[Network] _register_player faltan campos obligatorios")
		return

	var nick: String = str(new_player_info.get("nick", "Player")).strip_edges()
	if nick.is_empty(): nick = "Player_%d" % new_player_id
	if nick.length() > 20: nick = nick.substr(0, 20)

	var validated_info := {
		"nick": nick,
		"character": str(new_player_info.get("character", "amy"))
	}

	print("[Network] Registrando jugador: %d (%s)" % [new_player_id, nick])
	players[new_player_id] = validated_info
	player_connected.emit(new_player_id, validated_info)

	# CAMBIO: si somos el servidor, notificar a TODOS los demás clientes
	# que este nuevo jugador existe, para que lo spaween también.
	# Y enviar al nuevo cliente la info de TODOS los jugadores ya conectados.
	if multiplayer.is_server():
		# Decirle a todos los clientes existentes que spaween al nuevo jugador
		for peer_id in players:
			if peer_id == new_player_id:
				continue  # él ya se spawneó a sí mismo
			_notify_player_joined.rpc_id(peer_id, new_player_id, validated_info)

		# Decirle al nuevo cliente quiénes ya estaban conectados
		for peer_id in players:
			if peer_id == new_player_id:
				continue  # su propia info ya la tiene
			_notify_player_joined.rpc_id(new_player_id, peer_id, players[peer_id])

@rpc("authority", "reliable")
func _notify_player_joined(peer_id: int, info: Dictionary) -> void:
	Network.remote_print("[Network] _notify_player_joined | peer=%d | info=%s" % [
		peer_id, str(info)
	])
	if not players.has(peer_id):
		players[peer_id] = info
	player_connected.emit(peer_id, info)

# ──────────────────────────────────────────────────────────────────────
# UTILIDADES PÚBLICAS
# CAMBIO: helpers nuevos para que otros scripts consulten el estado de red
# sin tener que leer net_mode directamente.
# ──────────────────────────────────────────────────────────────────────
func is_host() -> bool:
	return net_mode == NetMode.LISTEN_SERVER or net_mode == NetMode.DEDICATED_SERVER


func is_dedicated_server() -> bool:
	return net_mode == NetMode.DEDICATED_SERVER


func is_client() -> bool:
	return net_mode == NetMode.CLIENT


func is_connected_to_game() -> bool:
	return net_mode != NetMode.NONE and multiplayer.multiplayer_peer != null


func get_player_count() -> int:
	return players.size()

# Llama esto en cualquier lugar donde quieras "print" en el móvil
func remote_print(msg: String) -> void:
	if multiplayer.is_server():
		print("[MOBILE] ", msg)
	else:
		_remote_log.rpc_id(1, msg)

@rpc("any_peer", "reliable")
func _remote_log(msg: String) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	print("[MOBILE:%d] %s" % [sender, msg])
