extends Node3D

@onready var players_container: Node3D = $PlayersContainer
@onready var main_menu: MainMenuUI = $MainMenuUI
@export var player_scene: PackedScene

@onready var multiplayer_chat: MultiplayerChatUI = $MultiplayerChatUI
@onready var crosshair: CanvasLayer = $CanvasLayer

const HUD_SCENE            = preload("res://scenes/ui/HUD.tscn")
const CHARACTER_SELECT_SCENE = preload("res://scenes/ui/character_select.tscn")
const GAME_MODE_SCENE      = preload("res://scenes/ui/game_mode_select.tscn")

var _char_select      : CharacterSelectUI  = null
var _game_mode_select : GameModeSelectUI   = null
var _hud              : CanvasLayer        = null

var _pending_nickname  : String = ""
var _pending_character : String = ""

var chat_visible = false

func _ready():
	if DisplayServer.get_name() == "headless":
		print("Dedicated server starting...")
		Network.start_host("", "")

	multiplayer_chat.hide()
	main_menu.show_menu()
	multiplayer_chat.set_process_input(true)

	# ── Señales ── (cada una conectada UNA sola vez)
	main_menu.open_character_select.connect(_on_open_character_select)
	main_menu.quit_pressed.connect(_on_quit_pressed)

	if multiplayer_chat:
		multiplayer_chat.message_sent.connect(_on_chat_message_sent)

	Network.server_disconnected.connect(_on_server_disconnected)

	if not multiplayer.is_server():
		return

	Network.connect("player_connected", Callable(self, "_on_player_connected"))
	multiplayer.peer_disconnected.connect(_remove_player)

func _on_server_disconnected():
	if _hud:
		_hud.queue_free()
		_hud = null
	for child in players_container.get_children():
		child.queue_free()
	chat_visible = false
	multiplayer_chat.hide()
	main_menu.show_menu()

func _on_player_connected(peer_id, player_info):
	_add_player(peer_id, player_info)

# ── FLUJO: Menú → Selector de personaje ───────────────────
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

# ── FLUJO: Selector de personaje → Selector de modo (solo host) ───
func _on_host_confirmed(nickname: String, character: String) -> void:
	if _char_select:
		_char_select.hide()

	# Guardar datos hasta que el host elija el modo
	_pending_nickname  = nickname
	_pending_character = character

	# Abrir selector de modo de juego
	if _game_mode_select == null:
		_game_mode_select = GAME_MODE_SCENE.instantiate()
		add_child(_game_mode_select)
		_game_mode_select.mode_confirmed.connect(_on_mode_confirmed)

	_game_mode_select.show()

# ── FLUJO: Selector de modo → Juego ───────────────────────
func _on_mode_confirmed(mode_id: String) -> void:
	if _game_mode_select:
		_game_mode_select.hide()

	crosshair.show()
	_spawn_hud(_pending_nickname)
	Network.start_host(_pending_nickname, _pending_character)

	# Guardar modo para usarlo en el juego
	GameManager.selected_mode = mode_id

# ── FLUJO: Join → directo al juego (sin selector de modo) ─
func _on_join_confirmed(nickname: String, character: String, address: String) -> void:
	if _char_select:
		_char_select.hide()
	crosshair.show()
	_spawn_hud(nickname)
	Network.join_game(nickname, character, address)

# ── Resto sin cambios ──────────────────────────────────────
func _spawn_hud(nickname: String) -> void:
	if _hud != null:
		return
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)
	_hud.set_nickname(nickname)

func _add_player(id: int, player_info: Dictionary):
	if DisplayServer.get_name() == "headless" and id == 1:
		return
	if players_container.has_node(str(id)):
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	player.position = get_spawn_point()
	players_container.add_child(player, true)

	var nick = Network.players[id]["nick"]
	player.nickname.text = nick

	var character_id = player_info["character"]
	var character_data = _load_character_data(character_id)
	if character_data:
		player.set_character(character_data)

	if id == multiplayer.get_unique_id() and _hud:
		var ab = _hud.get_action_buttons()
		if ab:
			ab.set_player(player)

func get_spawn_point() -> Vector3:
	var spawn_point = Vector2.from_angle(randf() * 2 * PI) * 10
	return Vector3(spawn_point.x, 0, spawn_point.y)

func _remove_player(id):
	if not multiplayer.is_server() or not players_container.has_node(str(id)):
		return
	var player_node = players_container.get_node(str(id))
	if player_node:
		player_node.queue_free()

func _on_quit_pressed() -> void:
	get_tree().quit()

func get_local_player():
	var local_player_id = multiplayer.get_unique_id()
	if players_container.has_node(str(local_player_id)):
		return players_container.get_node(str(local_player_id))
	return null

func toggle_chat():
	if main_menu.is_menu_visible():
		return
	multiplayer_chat.toggle_chat()
	chat_visible = multiplayer_chat.is_chat_visible()

func is_chat_visible() -> bool:
	return multiplayer_chat.is_chat_visible()

func _input(event):
	if event.is_action_pressed("toggle_chat"):
		toggle_chat()
	elif chat_visible and multiplayer_chat.message.has_focus():
		if event is InputEventKey and event.keycode == KEY_ENTER and event.pressed:
			multiplayer_chat._on_send_pressed()
			get_viewport().set_input_as_handled()

func _on_chat_message_sent(message_text: String) -> void:
	var trimmed_message = message_text.strip_edges()
	if trimmed_message == "":
		return
	var nick = Network.players[multiplayer.get_unique_id()]["nick"]
	rpc("msg_rpc", nick, trimmed_message)

@rpc("any_peer", "call_local")
func msg_rpc(nick, msg):
	multiplayer_chat.add_message(nick, msg)

func _load_character_data(character_id: String) -> CharacterData:
	var paths = {
		"amy":       "res://assets/characters/team_a/Amy/amy.tres",
		"michelle":  "res://assets/characters/team_a/Michelle/michelle.tres",
		"ortiz":     "res://assets/characters/team_a/Ortiz/ortiz.tres",
		"big_vegas": "res://assets/characters/team_b/Big Vegas/big_vegas.tres",
		"mousey":    "res://assets/characters/team_b/Mousey/mousey.tres"
	}
	if character_id in paths:
		return load(paths[character_id])
	return null

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
