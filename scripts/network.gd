extends Node

const SERVER_PORT: int = 7777
const MAX_PLAYERS: int = 10

var players = {}
var player_info = {
	"nick": "host",
	"character": "amy"
}

signal player_connected(peer_id, player_info)
signal server_disconnected

func _process(_delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit(0)

func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.connected_to_server.connect(_on_connected_ok)

# ------------------ HOST ------------------

func start_host(nickname: String, character_id: String):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(SERVER_PORT, MAX_PLAYERS)
	
	if error != OK:
		print("Error al crear servidor: ", error)
		return error
	
	multiplayer.multiplayer_peer = peer
	print("Servidor iniciado en puerto ", SERVER_PORT)

	if !nickname or nickname.strip_edges() == "":
		nickname = "Host_" + str(multiplayer.get_unique_id())

	player_info["nick"] = nickname
	player_info["character"] = character_id

	if DisplayServer.get_name() == "headless":
		return

	players[1] = player_info
	player_connected.emit(1, player_info)

# ------------------ CLIENTE ------------------

func join_game(nickname: String, character_id: String, address: String):
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, SERVER_PORT)

	if error != OK:
		print("Error al conectar: ", error)
		return error

	multiplayer.multiplayer_peer = peer
	print("Intentando conectar a: ", address, ":", SERVER_PORT)

	if !nickname or nickname.strip_edges() == "":
		nickname = "Player_" + str(multiplayer.get_unique_id())

	player_info["nick"] = nickname
	player_info["character"] = character_id

# ------------------ EVENTOS ------------------

func _on_connected_ok():
	print("Conectado al servidor")

	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	player_connected.emit(peer_id, player_info)

func _on_connection_failed():
	print("Fallo la conexión")
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()

func _on_server_disconnected():
	print("Servidor desconectado")
	multiplayer.multiplayer_peer = null
	players.clear()
	server_disconnected.emit()

func _on_player_connected(id):
	print("Jugador conectado: ", id)

	if DisplayServer.get_name() == "headless":
		return

	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	print("Registrando jugador: ", new_player_id)

	players[new_player_id] = new_player_info
	player_connected.emit(new_player_id, new_player_info)

func _on_player_disconnected(id):
	print("Jugador desconectado: ", id)
	players.erase(id)
