extends Control
class_name CharacterSelectUI

var _nickname : String = ""
var _address  : String = ""
var _is_host  : bool   = true

signal host_confirmed(nickname: String, character: String)
signal join_confirmed(nickname: String, character: String, address: String)

@onready var background       : ColorRect           = $Background
@onready var bando1_btn       : Button              = $FactionTabBar/BandoBtn1
@onready var bando2_btn       : Button              = $FactionTabBar/BandoBtn2
@onready var char_list        : VBoxContainer       = $VBoxContainer
@onready var char_name_label  : Label               = $InfoPanel/CharName
@onready var stat_role        : Label               = $InfoPanel/StatRole
@onready var stat_health      : Label               = $InfoPanel/StatHealth
@onready var stat_damage      : Label               = $InfoPanel/StatDamage
@onready var start_btn        : Button              = $StartButton
@onready var back_btn         : Button              = $BackButton
@onready var viewport_container : SubViewportContainer = $ViewportContainer
@onready var char_model_root  : Node3D              = $ViewportContainer/SubViewport/CharacterScene/CharacterModel

const COLOR_BANDO1 := Color(0.1, 0.45, 0.5)
const COLOR_BANDO2 := Color(0.55, 0.15, 0.05)

const CHARACTERS := {
	"bando1": [
		{ "id": "amy",      "name": "Amy",      "role": "Todoterreno", "health": 100, "damage": 15,
			"scene": "res://assets/characters/team_a/Amy/amy.tres" },
		{ "id": "michelle", "name": "Michelle", "role": "Soporte",     "health": 120, "damage": 10,
			"scene": "res://assets/characters/team_a/Michelle/michelle.tres" },
		{ "id": "ortiz",    "name": "Ortiz",    "role": "Asalto",      "health": 90,  "damage": 20,
			"scene": "res://assets/characters/team_a/Ortiz/ortiz.tres" },
		{ "id": "char4",    "name": "???",      "role": "???",         "health": 0,   "damage": 0,
			"scene": "" },
	],
	"bando2": [
		{ "id": "big_vegas","name": "Big Vegas","role": "Tanque",      "health": 150, "damage": 12,
			"scene": "res://assets/characters/team_b/Big Vegas/big_vegas.tres" },
		{ "id": "mousey",   "name": "Mousey",   "role": "Asesino",     "health": 80,  "damage": 25,
			"scene": "res://assets/characters/team_b/Mousey/mousey.tres" },
		{ "id": "char3",    "name": "???",      "role": "???",         "health": 0,   "damage": 0,
			"scene": "" },
		{ "id": "char4b",   "name": "???",      "role": "???",         "health": 0,   "damage": 0,
			"scene": "" },
	]
}

var _current_bando  : String = "bando1"
var _current_idx    : int    = 0
var _current_model  : Node3D = null
var _is_dragging    : bool   = false
var _drag_last_x    : float  = 0.0
var _char_buttons   : Array  = []

func setup(nickname: String, address: String, is_host: bool) -> void:
	_nickname = nickname
	_address  = address
	_is_host  = is_host

func _ready() -> void:
	# Recopilar los 4 botones del VBoxContainer
	for btn in char_list.get_children():
		if btn is Button:
			var idx = _char_buttons.size()
			_char_buttons.append(btn)
			btn.pressed.connect(_select_character.bind(idx))

	bando1_btn.pressed.connect(func(): _load_bando("bando1"))
	bando2_btn.pressed.connect(func(): _load_bando("bando2"))
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	viewport_container.gui_input.connect(_on_viewport_input)

	_load_bando("bando1")

func _load_bando(bando: String) -> void:
	_current_bando = bando
	_current_idx   = 0
	background.color = COLOR_BANDO1 if bando == "bando1" else COLOR_BANDO2

	var chars : Array = CHARACTERS[bando]
	for i in _char_buttons.size():
		_char_buttons[i].text = chars[i]["name"] if i < chars.size() else ""

	_select_character(0)

func _select_character(index: int) -> void:
	_current_idx = index
	var data : Dictionary = CHARACTERS[_current_bando][index]

	char_name_label.text = data["name"]
	stat_role.text       = "Rol: "  + data["role"]
	stat_health.text     = "Vida: " + str(data["health"])
	stat_damage.text     = "Daño: " + str(data["damage"])

	for i in _char_buttons.size():
		_char_buttons[i].flat = (i != index)

	# Solo cargar si tiene escena asignada
	if data["scene"] != "":
		_load_model(data["scene"])
	else:
		# Limpiar modelo si es personaje bloqueado
		if _current_model:
			_current_model.queue_free()
			_current_model = null

func _load_model(scene_path: String) -> void:
	if _current_model:
		_current_model.queue_free()
		_current_model = null

	# Cargar el CharacterData .tres en lugar de la escena directamente
	var char_data : CharacterData = load(scene_path)
	if not char_data or not char_data.model_scene:
		return

	# Instanciar solo el modelo visual
	_current_model = char_data.model_scene.instantiate()
	char_model_root.add_child(_current_model)
	_current_model.scale = Vector3.ONE * char_data.preview_scale

	# Deshabilitar tracks de posición del root bone (igual que en Character.gd)
	var anim_player : AnimationPlayer = _current_model.get_node_or_null("AnimationPlayer")
	if not anim_player:
		return

	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		for i in range(anim.get_track_count()):
			var path = str(anim.track_get_path(i))
			if path.contains("mixamorig_Hips") and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				anim.track_set_enabled(i, false)

	anim_player.play("IDLE_ANIM")

func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_dragging = event.pressed
		_drag_last_x = event.position.x

	elif event is InputEventMouseMotion and _is_dragging:
		var delta : float = event.position.x - _drag_last_x
		if _current_model:
			_current_model.rotate_y(delta * 0.005)
		_drag_last_x = event.position.x

	elif event is InputEventScreenDrag:
		if _current_model:
			_current_model.rotate_y(event.relative.x * 0.005)

func _on_back_pressed() -> void:
	hide()
	get_parent().show_main_menu_from_character_select()

func _on_start_pressed() -> void:
	var char_id : String = CHARACTERS[_current_bando][_current_idx]["id"]
	if _is_host:
		host_confirmed.emit(_nickname, char_id)
	else:
		join_confirmed.emit(_nickname, char_id, _address)
