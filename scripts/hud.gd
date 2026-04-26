# hud.gd
extends CanvasLayer

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var _nickname_label : Label       = $Control/PanelContainer/VBoxContainer/NicknameLabel
@onready var _life_label     : Label       = $Control/PanelContainer/VBoxContainer/HBoxContainer/LifeContainer/LifeLabel
@onready var _ammo_label     : Label       = $Control/PanelContainer/VBoxContainer/HBoxContainer/AmmoContainer/AmmoLabel
@onready var _heart_icon: TextureRect = $Control/PanelContainer/VBoxContainer/HBoxContainer/LifeContainer/HeartIcon
@onready var _bullet_icon: TextureRect = $Control/PanelContainer/VBoxContainer/HBoxContainer/AmmoContainer/BulletIcon

const BULLET_SHEET = preload("res://assets/ui/2D Pickups v6.2 spritesheet.png")  # ajusta la ruta
const HEART_SHEET = preload("res://assets/ui/heart_animated_2.png")  # ajusta la ruta
const GEAR_TEXTURE = preload("res://assets/ui/gear.png")

var _bullet_atlas: AtlasTexture = null
var _gear_rotation: float = 0.0
var _showing_gear: bool = false
var _left_joystick_active: bool = false

@onready var _dpad: DPad = $MarginContainer/DPad
@onready var _action_buttons: ActionButtons = $ActionButtons

func get_action_buttons() -> ActionButtons:
	return _action_buttons

func get_dpad() -> DPad:
	return _dpad

# ── Referencia al personaje local ─────────────────────────────────────────
var _character = null

func _ready() -> void:
	var atlas_heart = AtlasTexture.new()
	atlas_heart.atlas = HEART_SHEET
	atlas_heart.region = Rect2(0, 0, 17, 17)
	_heart_icon.texture = atlas_heart
	_heart_icon.custom_minimum_size = Vector2(17, 17)

	_bullet_atlas = AtlasTexture.new()
	_bullet_atlas.atlas = BULLET_SHEET
	_bullet_atlas.region = Rect2(0, 32, 32, 32)
	_bullet_icon.texture = _bullet_atlas
	_bullet_icon.custom_minimum_size = Vector2(32, 32)

	var panel = $Control/PanelContainer
	panel.custom_minimum_size = Vector2(180, 68)

	await get_tree().process_frame
	await get_tree().process_frame
	_reposition_panel()


	print("Viewport size: ", get_viewport().get_visible_rect().size)


	while _character == null:
		var level = get_tree().get_current_scene()
		_character = level.get_local_player()
		if _character == null:
			await get_tree().create_timer(0.1).timeout

# ── Update por frame ──────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _character == null:
		return
	
	_life_label.text = str(int(_character.health))
	_update_heart_icon()
	
	if _character._is_reloading:
		# Cambia al engranaje si aún no lo hizo
		if not _showing_gear:
			_showing_gear = true
			_bullet_icon.texture = GEAR_TEXTURE
			_bullet_icon.pivot_offset = Vector2(16, 16)  # centro del ícono
			
		# Gira el engranaje
		_gear_rotation += delta * 180.0  # 180 grados por segundo
		_bullet_icon.rotation_degrees = _gear_rotation
		
		var remaining = ceil(_character._reload_timer)
		_ammo_label.text = "  %d..." % remaining
		
	else:
		# Regresa al ícono de bala
		if _showing_gear:
			_showing_gear = false
			_bullet_icon.texture = _bullet_atlas
			_bullet_icon.rotation_degrees = 0.0
			_gear_rotation = 0.0
		
		_ammo_label.text = "%d/%d" % [_character.ammo_current, _character.ammo_reserve]

# ── API pública ────────────────────────────────────────────────────────────

# Llama esto desde Character.gd cuando cambie el nick via RPC
func set_nickname(nick: String) -> void:
	_nickname_label.text = nick

# Llama esto si quieres forzar un refresco inmediato de vida
# (útil al recibir sync_health vía RPC)
func refresh_health(new_health: float) -> void:
	_life_label.text = str(int(new_health))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_reposition_panel()

func _reposition_panel() -> void:
	var panel = $Control/PanelContainer
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = panel.size.x if panel.size.x > 0 else 180.0
	panel.position = Vector2(
		viewport_size.x - panel_width - 26,
		22
	)
	
func _update_heart_icon() -> void:
	if _character == null:
		return
	# 0 = lleno, 4 = vacío según porcentaje de vida
	var ratio = _character.health / _character.max_health
	var frame = 0
	if ratio > 0.75:
		frame = 0
	elif ratio > 0.50:
		frame = 1
	elif ratio > 0.25:
		frame = 2
	elif ratio > 0.0:
		frame = 3
	else:
		frame = 4
	
	var atlas = _heart_icon.texture as AtlasTexture
	atlas.region = Rect2(frame * 17, 0, 17, 17)
