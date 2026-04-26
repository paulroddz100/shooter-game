extends Control
class_name ActionButtons

signal shoot_pressed
signal shoot_released

var _touch_a: int = -1
var _touch_b: int = -1

@onready var _btn_a: Button = $BtnA
@onready var _btn_b: Button = $BtnB
var _player: Character = null

func set_player(player: Character) -> void:
	_player = player

func _ready() -> void:
	_btn_a.text = "A"
	_btn_b.text = "B"
	_setup_button_style(_btn_a, Color(0.6, 0.1, 0.1, 0.6))
	_setup_button_style(_btn_b, Color(0.1, 0.1, 0.6, 0.6))

func _setup_button_style(btn: Button, color: Color) -> void:
	btn.self_modulate = Color(1, 1, 1, 0.5)
	btn.add_theme_stylebox_override("normal", _make_style(color, 2))
	btn.add_theme_stylebox_override("hover", _make_style(color, 2))
	btn.add_theme_stylebox_override("pressed", _make_style(color, 2))
	btn.add_theme_stylebox_override("focus", _make_style(color, 2))

func _make_style(bg: Color, border_width: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = border_width
	s.border_width_top = border_width
	s.border_width_right = border_width
	s.border_width_bottom = border_width
	s.border_color = Color(1, 1, 1, 0.9)
	s.corner_radius_top_left = 999
	s.corner_radius_top_right = 999
	s.corner_radius_bottom_left = 999
	s.corner_radius_bottom_right = 999
	return s

func _set_pressed_style(btn: Button, color: Color, is_pressed: bool) -> void:
	if is_pressed:
		btn.self_modulate = Color(1, 1, 1, 1.0)
		btn.add_theme_stylebox_override("normal", _make_style(color, 4))
	else:
		btn.self_modulate = Color(1, 1, 1, 0.5)
		btn.add_theme_stylebox_override("normal", _make_style(color, 2))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_a == -1 and _is_inside(_btn_a, event.position):
				_touch_a = event.index
				if _player:
					_player._shooting_mobile = true
				_set_pressed_style(_btn_a, Color(0.6, 0.1, 0.1, 0.6), true)
			elif _touch_b == -1 and _is_inside(_btn_b, event.position):
				_touch_b = event.index
				Input.action_press("jump")
				_set_pressed_style(_btn_b, Color(0.1, 0.1, 0.6, 0.6), true)
		else:
			if event.index == _touch_a:
				_touch_a = -1
				if _player:
					_player._shooting_mobile = false
				_set_pressed_style(_btn_a, Color(0.6, 0.1, 0.1, 0.6), false)
			elif event.index == _touch_b:
				_touch_b = -1
				Input.action_release("jump")
				_set_pressed_style(_btn_b, Color(0.1, 0.1, 0.6, 0.6), false)

func _is_inside(btn: Button, pos: Vector2) -> bool:
	if not btn:
		return false
	return btn.get_global_rect().has_point(pos)

func get_active_touches() -> Array:
	var touches = []
	for t in [_touch_a, _touch_b]:
		if t != -1:
			touches.append(t)
	return touches
