extends Control
class_name DPad

var _touch_up: int = -1
var _touch_down: int = -1
var _touch_left: int = -1
var _touch_right: int = -1
var _touch_diag_left: int = -1
var _touch_diag_right: int = -1
var _drag_direction: int = 0

var _up_pressed: bool = false

@onready var _btn_up: Button = $Up
@onready var _btn_down: Button = $Down
@onready var _btn_left: Button = $Left
@onready var _btn_right: Button = $Right
@onready var _btn_diag_left: Button = $DiagLeft
@onready var _btn_diag_right: Button = $DiagRight

func _ready() -> void:
	_btn_diag_left.visible = false
	_btn_diag_right.visible = false
	_btn_up.text = "▲"
	_btn_down.text = "▼"
	_btn_left.text = "◀"
	_btn_right.text = "▶"
	_btn_diag_left.text = "↖"
	_btn_diag_right.text = "↗"
	for btn in [_btn_up, _btn_down, _btn_left, _btn_right, _btn_diag_left, _btn_diag_right]:
		_setup_button_style(btn)

func _setup_button_style(btn: Button) -> void:
	btn.self_modulate = Color(1, 1, 1, 0.5)
	btn.add_theme_stylebox_override("normal", _make_style(Color(0.2, 0.2, 0.2, 0.5), 2))
	btn.add_theme_stylebox_override("hover", _make_style(Color(0.2, 0.2, 0.2, 0.5), 2))
	btn.add_theme_stylebox_override("pressed", _make_style(Color(0.2, 0.2, 0.2, 0.5), 2))
	btn.add_theme_stylebox_override("focus", _make_style(Color(0.2, 0.2, 0.2, 0.5), 2))

func _make_style(bg: Color, border_width: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = border_width
	s.border_width_top = border_width
	s.border_width_right = border_width
	s.border_width_bottom = border_width
	s.border_color = Color(1, 1, 1, 0.9)
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	return s

func _set_pressed_style(btn: Button, is_pressed: bool) -> void:
	if is_pressed:
		btn.self_modulate = Color(1, 1, 1, 1.0)
		btn.add_theme_stylebox_override("normal", _make_style(Color(0.5, 0.5, 0.5, 0.8), 4))
	else:
		btn.self_modulate = Color(1, 1, 1, 0.5)
		btn.add_theme_stylebox_override("normal", _make_style(Color(0.2, 0.2, 0.2, 0.5), 2))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_any_button(event.position):
				_handle_press(event.index, event.position)
		else:
			_handle_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _touch_up:
			_handle_up_drag(event.index, event.position)
		elif event.index == _touch_left:
			_handle_left_drag(event.index, event.position)
		elif event.index == _touch_right:
			_handle_right_drag(event.index, event.position)
		elif event.index == _touch_down:
			pass

func _is_any_button(pos: Vector2) -> bool:
	for btn in [_btn_up, _btn_down, _btn_left, _btn_right, _btn_diag_left, _btn_diag_right]:
		if btn.visible and _is_inside(btn, pos):
			return true
	return false

func _handle_up_drag(index: int, pos: Vector2) -> void:
	# Si el dedo se desliza al botón lateral, transfiere el control
	if _is_inside(_btn_left, pos):
		_release_up_drag()
		_touch_up = -1
		_up_pressed = false
		_btn_diag_left.visible = false
		_btn_diag_right.visible = false
		Input.action_release("move_forward")
		_set_pressed_style(_btn_up, false)
		_touch_left = index
		Input.action_press("move_left")
		_set_pressed_style(_btn_left, true)
		return
	elif _is_inside(_btn_right, pos):
		_release_up_drag()
		_touch_up = -1
		_up_pressed = false
		_btn_diag_left.visible = false
		_btn_diag_right.visible = false
		Input.action_release("move_forward")
		_set_pressed_style(_btn_up, false)
		_touch_right = index
		Input.action_press("move_right")
		_set_pressed_style(_btn_right, true)
		return

	var btn_up_rect = _btn_up.get_global_rect()
	var center_x = btn_up_rect.get_center().x
	var threshold = btn_up_rect.size.x * 0.3

	var new_dir = 0
	if pos.x < center_x - threshold:
		new_dir = -1
	elif pos.x > center_x + threshold:
		new_dir = 1

	if new_dir == _drag_direction:
		return

	_release_up_drag()
	_drag_direction = new_dir

	if new_dir == -1:
		Input.action_press("move_left")
		_set_pressed_style(_btn_diag_left, true)
	elif new_dir == 1:
		Input.action_press("move_right")
		_set_pressed_style(_btn_diag_right, true)

func _release_up_drag() -> void:
	if _drag_direction == -1 and _touch_left == -1:
		Input.action_release("move_left")
		_set_pressed_style(_btn_diag_left, false)
	elif _drag_direction == 1 and _touch_right == -1:
		Input.action_release("move_right")
		_set_pressed_style(_btn_diag_right, false)
	_drag_direction = 0

func _handle_left_drag(index: int, pos: Vector2) -> void:
	if not _is_inside(_btn_left, pos):
		_touch_left = -1
		Input.action_release("move_left")
		_set_pressed_style(_btn_left, false)
		if _is_inside(_btn_up, pos) and _touch_up == -1:
			_touch_up = index
			_up_pressed = true
			_btn_diag_left.visible = true
			_btn_diag_right.visible = true
			Input.action_press("move_forward")
			_set_pressed_style(_btn_up, true)

func _handle_right_drag(index: int, pos: Vector2) -> void:
	if not _is_inside(_btn_right, pos):
		_touch_right = -1
		Input.action_release("move_right")
		_set_pressed_style(_btn_right, false)
		if _is_inside(_btn_up, pos) and _touch_up == -1:
			_touch_up = index
			_up_pressed = true
			_btn_diag_left.visible = true
			_btn_diag_right.visible = true
			Input.action_press("move_forward")
			_set_pressed_style(_btn_up, true)

func _handle_press(index: int, pos: Vector2) -> void:
	if _touch_up == -1 and _is_inside(_btn_up, pos):
		_touch_up = index
		_up_pressed = true
		_btn_diag_left.visible = true
		_btn_diag_right.visible = true
		Input.action_press("move_forward")
		_set_pressed_style(_btn_up, true)
	elif _touch_down == -1 and _is_inside(_btn_down, pos):
		_touch_down = index
		Input.action_press("move_backward")
		_set_pressed_style(_btn_down, true)
	elif _touch_left == -1 and _is_inside(_btn_left, pos):
		_touch_left = index
		Input.action_press("move_left")
		_set_pressed_style(_btn_left, true)
	elif _touch_right == -1 and _is_inside(_btn_right, pos):
		_touch_right = index
		Input.action_press("move_right")
		_set_pressed_style(_btn_right, true)
	elif _up_pressed and _touch_diag_left == -1 and _is_inside(_btn_diag_left, pos):
		_touch_diag_left = index
		Input.action_press("move_left")
		_set_pressed_style(_btn_diag_left, true)
	elif _up_pressed and _touch_diag_right == -1 and _is_inside(_btn_diag_right, pos):
		_touch_diag_right = index
		Input.action_press("move_right")
		_set_pressed_style(_btn_diag_right, true)

func _handle_release(index: int) -> void:
	if index == _touch_up:
		_touch_up = -1
		_up_pressed = false
		_release_up_drag()
		_btn_diag_left.visible = false
		_btn_diag_right.visible = false
		if _touch_diag_left != -1:
			_touch_diag_left = -1
			_set_pressed_style(_btn_diag_left, false)
		if _touch_diag_right != -1:
			_touch_diag_right = -1
			_set_pressed_style(_btn_diag_right, false)
		if _touch_left == -1:
			Input.action_release("move_left")
		if _touch_right == -1:
			Input.action_release("move_right")
		Input.action_release("move_forward")
		_set_pressed_style(_btn_up, false)
		_set_pressed_style(_btn_diag_left, false)
		_set_pressed_style(_btn_diag_right, false)
	elif index == _touch_down:
		_touch_down = -1
		Input.action_release("move_backward")
		_set_pressed_style(_btn_down, false)
	elif index == _touch_left:
		_touch_left = -1
		if _drag_direction != -1:
			Input.action_release("move_left")
		_set_pressed_style(_btn_left, false)
	elif index == _touch_right:
		_touch_right = -1
		if _drag_direction != 1:
			Input.action_release("move_right")
		_set_pressed_style(_btn_right, false)
	elif index == _touch_diag_left:
		_touch_diag_left = -1
		if _drag_direction != -1 and _touch_left == -1:
			Input.action_release("move_left")
		_set_pressed_style(_btn_diag_left, false)
	elif index == _touch_diag_right:
		_touch_diag_right = -1
		if _drag_direction != 1 and _touch_right == -1:
			Input.action_release("move_right")
		_set_pressed_style(_btn_diag_right, false)

func _is_inside(btn: Button, pos: Vector2) -> bool:
	return btn.get_global_rect().has_point(pos)

func get_active_touches() -> Array:
	var touches = []
	for t in [_touch_up, _touch_down, _touch_left, _touch_right, _touch_diag_left, _touch_diag_right]:
		if t != -1:
			touches.append(t)
	return touches
