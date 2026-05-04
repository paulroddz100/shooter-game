extends CanvasLayer
 
# ──────────────────────────────────────────────────────────────────────
# NODOS DEL HUD ORIGINAL
# ──────────────────────────────────────────────────────────────────────
@onready var _nickname_label : Label       = $Control/PanelContainer/VBoxContainer/NicknameLabel
@onready var _life_label     : Label       = $Control/PanelContainer/VBoxContainer/HBoxContainer/LifeContainer/LifeLabel
@onready var _ammo_label     : Label       = $Control/PanelContainer/VBoxContainer/HBoxContainer/AmmoContainer/AmmoLabel
@onready var _heart_icon: TextureRect = $Control/PanelContainer/VBoxContainer/HBoxContainer/LifeContainer/HeartIcon
@onready var _bullet_icon: TextureRect = $Control/PanelContainer/VBoxContainer/HBoxContainer/AmmoContainer/BulletIcon
 
@onready var _dpad: DPad = $MarginContainer/DPad
@onready var _action_buttons: ActionButtons = $MarginContainer2/ActionButtons
 
# ──────────────────────────────────────────────────────────────────────
# NODOS DEL MATCH UI (configurados en el editor)
# Estructura: MatchUI/ScoreboardContainer/[ScoreAPanel | CenterPanel | ScoreBPanel]
# ──────────────────────────────────────────────────────────────────────
@onready var _score_a_label    : Label = $MatchUI/ScoreboardContainer/ScoreAPanel/ScoreA
@onready var _score_b_label    : Label = $MatchUI/ScoreboardContainer/ScoreBPanel/ScoreB
@onready var _center_label     : Label = $MatchUI/ScoreboardContainer/CenterPanel/CenterLabel
@onready var _countdown_label  : Label = $MatchUI/CountdownLabel
 
# ──────────────────────────────────────────────────────────────────────
# CONSTANTES
# ──────────────────────────────────────────────────────────────────────
const BULLET_SHEET = preload("res://assets/ui/2D Pickups v6.2 spritesheet.png")
const HEART_SHEET = preload("res://assets/ui/heart_animated_2.png")
const GEAR_TEXTURE = preload("res://assets/ui/gear.png")
 
const COLOR_CELESTE := Color(0.0, 0.318, 0.957, 1.0)
const COLOR_ROJO    := Color(0.898, 0.0, 0.204, 1.0)
const COLOR_BLANCO  := Color.WHITE
const COLOR_TIMER_WARNING := Color(0.9, 0.15, 0.15)
 
# ──────────────────────────────────────────────────────────────────────
# ESTADO
# ──────────────────────────────────────────────────────────────────────
var _bullet_atlas: AtlasTexture = null
var _gear_rotation: float = 0.0
var _showing_gear: bool = false
var _left_joystick_active: bool = false
var _character = null
 
 
# ──────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ──────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_icons()
	_setup_panel()
	_connect_match_signals()
 
	await get_tree().process_frame
	await get_tree().process_frame
	_reposition_panel()
	print("Viewport size: ", get_viewport().get_visible_rect().size)
 
	# Esperar a que el jugador local exista
	while _character == null:
		var level = get_tree().get_current_scene()
		_character = level.get_local_player()
		if _character == null:
			await get_tree().create_timer(0.1).timeout
 
	_apply_initial_match_ui_state()
 
 
func _setup_icons() -> void:
	var atlas_heart := AtlasTexture.new()
	atlas_heart.atlas = HEART_SHEET
	atlas_heart.region = Rect2(0, 0, 17, 17)
	_heart_icon.texture = atlas_heart
	_heart_icon.custom_minimum_size = Vector2(42, 42)
 
	_bullet_atlas = AtlasTexture.new()
	_bullet_atlas.atlas = BULLET_SHEET
	_bullet_atlas.region = Rect2(0, 32, 32, 32)
	_bullet_icon.texture = _bullet_atlas
	_bullet_icon.custom_minimum_size = Vector2(17, 17)
 
	_heart_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_heart_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 
 
func _setup_panel() -> void:
	var life_container = $Control/PanelContainer/VBoxContainer/HBoxContainer/LifeContainer
	life_container.size_flags_horizontal = Control.SIZE_FILL
 
	var panel = $Control/PanelContainer
	panel.custom_minimum_size = Vector2(180, 68)
 
 
func _connect_match_signals() -> void:
	GameManager.score_updated.connect(_on_score_updated)
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.countdown_tick.connect(_on_countdown_tick)
	GameManager.match_started.connect(_on_match_started_hud)
	GameManager.match_ended.connect(_on_match_ended_hud)
 
 
func _apply_initial_match_ui_state() -> void:
	# Inicializar scores en cero
	if _score_a_label:
		_score_a_label.text = "0"
	if _score_b_label:
		_score_b_label.text = "0"
 
	# Centro del marcador: timer o "vs." según el modo
	if _center_label:
		if GameManager.selected_mode == "time_battle":
			# Mostrar formato de tiempo inicial
			var total := int(GameManager.TIME_BATTLE_DURATION)
			var minutes := total / 60
			var seconds := total % 60
			_center_label.text = "%02d:%02d" % [minutes, seconds]
		else:
			# Modo deathmatch o cualquier otro: mostrar "vs."
			_center_label.text = "vs."
 
 
# ──────────────────────────────────────────────────────────────────────
# UPDATE POR FRAME (vida y munición)
# ──────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _character == null:
		return
 
	_life_label.text = str(int(_character.health))
	_update_heart_icon()
 
	if _character._is_reloading:
		_show_reload_animation(delta)
	else:
		_show_normal_ammo()
 
 
func _show_reload_animation(delta: float) -> void:
	if not _showing_gear:
		_showing_gear = true
		_bullet_icon.texture = GEAR_TEXTURE
		_bullet_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		_bullet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_bullet_icon.custom_minimum_size = Vector2(32, 32)
		await get_tree().process_frame
		_bullet_icon.pivot_offset = _bullet_icon.size / 2.0
 
	_gear_rotation += delta * 180.0
	_bullet_icon.rotation_degrees = _gear_rotation
 
	var remaining = ceil(_character._reload_timer)
	_ammo_label.text = "  %d..." % remaining
 
 
func _show_normal_ammo() -> void:
	if _showing_gear:
		_showing_gear = false
		_bullet_icon.texture = _bullet_atlas
		_bullet_icon.rotation_degrees = 0.0
		_gear_rotation = 0.0
		_bullet_icon.pivot_offset = Vector2.ZERO
 
	_ammo_label.text = "%d/%d" % [_character.ammo_current, _character.ammo_reserve]
 
 
# ──────────────────────────────────────────────────────────────────────
# API PÚBLICA
# ──────────────────────────────────────────────────────────────────────
func set_nickname(nick: String) -> void:
	_nickname_label.text = nick
 
 
func refresh_health(new_health: float) -> void:
	_life_label.text = str(int(new_health))
 
 
func get_action_buttons() -> ActionButtons:
	return _action_buttons
 
 
func get_dpad() -> DPad:
	return _dpad
 
 
# ──────────────────────────────────────────────────────────────────────
# REPOSICIONAMIENTO Y ACTUALIZACIONES VISUALES
# ──────────────────────────────────────────────────────────────────────
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
 
 
# ──────────────────────────────────────────────────────────────────────
# CALLBACKS DEL GAME MANAGER
# ──────────────────────────────────────────────────────────────────────
func _on_score_updated(team_a: int, team_b: int) -> void:
	if _score_a_label:
		_score_a_label.text = str(team_a)
	if _score_b_label:
		_score_b_label.text = str(team_b)
 
 
func _on_time_updated(remaining: float) -> void:
	# Solo actualizar el centro si estamos en modo time_battle
	if GameManager.selected_mode != "time_battle":
		return
	if not _center_label:
		return
 
	var minutes := int(remaining) / 60
	var seconds := int(remaining) % 60
	_center_label.text = "%02d:%02d" % [minutes, seconds]
 
	# Cambiar color a rojo cuando queden menos de 15 segundos
	if remaining <= 15.0:
		_center_label.add_theme_color_override("font_color", COLOR_TIMER_WARNING)
	else:
		# Negro normal sobre fondo amarillo
		_center_label.add_theme_color_override("font_color", Color.BLACK)
 
 
func _on_countdown_tick(seconds_left: int) -> void:
	if not _countdown_label:
		return
	_countdown_label.visible = true
	_countdown_label.add_theme_color_override("font_color", COLOR_BLANCO)
	_countdown_label.text = str(seconds_left)
 
 
func _on_match_started_hud() -> void:
	if not _countdown_label:
		return
	_countdown_label.text = "¡VAMOS!"
	await get_tree().create_timer(1.0).timeout
	_countdown_label.visible = false
 
 
func _on_match_ended_hud(winning_team: int) -> void:
	if not _countdown_label:
		return
 
	_countdown_label.visible = true
 
	if winning_team == GameManager.Team.NONE:
		_countdown_label.text = "EMPATE"
		_countdown_label.add_theme_color_override("font_color", COLOR_BLANCO)
	elif winning_team == GameManager.Team.TEAM_A:
		_countdown_label.text = "GANÓ EL EQUIPO CELESTE"
		_countdown_label.add_theme_color_override("font_color", COLOR_CELESTE)
	else:
		_countdown_label.text = "GANÓ EL EQUIPO ROJO"
		_countdown_label.add_theme_color_override("font_color", COLOR_ROJO)
