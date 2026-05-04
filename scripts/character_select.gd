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

const COLOR_BANDO1 := Color(0.102, 0.184, 0.502, 1.0)
const COLOR_BANDO2 := Color(0.507, 0.057, 0.012, 1.0)

const CHARACTERS := {
	"bando1": [
		{ "id": "amy",      "name": "Amy",      "role": "Todoterreno", "health": 100, "damage": 15,
			"scene": "res://assets/characters/team_a/Amy/amy.tres" },
		{ "id": "michelle", "name": "Michelle", "role": "Soporte",     "health": 120, "damage": 10,
			"scene": "res://assets/characters/team_a/Michelle/michelle.tres" },
		{ "id": "ortiz",    "name": "Ortiz",    "role": "Asalto",      "health": 90,  "damage": 20,
			"scene": "res://assets/characters/team_a/Ortiz/ortiz.tres" },
		{ "id": "kaya",    "name": "Kaya",      "role": "Francotirador",         "health": 80,   "damage": 80,
			"scene": "res://assets/characters/team_a/Kaya/kaya.tres" },
	],
	"bando2": [
		{ "id": "mousey",   "name": "Mousey",   "role": "Asesino",     "health": 80,  "damage": 25,
			"scene": "res://assets/characters/team_b/Mousey/mousey.tres" },
		{ "id": "big_vegas","name": "Big Vegas","role": "Tanque",      "health": 150, "damage": 12,
			"scene": "res://assets/characters/team_b/Big Vegas/big_vegas.tres" },
		{ "id": "char3",    "name": "Timmy",      "role": "???",         "health": 0,   "damage": 0,
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


# ──────────────────────────────────────────────────────────────────────
# CONFIRMACIÓN CON VALIDACIÓN DE BANDO
# ──────────────────────────────────────────────────────────────────────
func _on_start_pressed() -> void:
	var char_data : Dictionary = CHARACTERS[_current_bando][_current_idx]
	var char_id : String = char_data["id"]

	# Validar que el personaje no sea un placeholder bloqueado
	if char_data.get("scene", "") == "":
		_show_error("Personaje no disponible")
		return

	# Validación de bando solo para clientes (no para el host).
	# El host inicia primero y siempre tiene espacio en su bando.
	if not _is_host:
		var target_team: int
		if _current_bando == "bando1":
			target_team = GameManager.Team.TEAM_A
		else:
			target_team = GameManager.Team.TEAM_B

		if not GameManager.can_join_team(target_team):
			_show_error("Este bando está lleno o desbalancearía los equipos.\nPor favor elige el otro bando.")
			return

	# Confirmar selección
	if _is_host:
		host_confirmed.emit(_nickname, char_id)
	else:
		join_confirmed.emit(_nickname, char_id, _address)


# Muestra un mensaje temporal en pantalla durante 3 segundos
func _show_error(message: String) -> void:
	var error_label := Label.new()
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	error_label.add_theme_font_size_override("font_size", 20)
	error_label.position = Vector2(
		get_viewport().get_visible_rect().size.x / 2 - 200,
		get_viewport().get_visible_rect().size.y - 150
	)
	error_label.size = Vector2(400, 60)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(error_label)

	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(error_label):
		error_label.queue_free()
