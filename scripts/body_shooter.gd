extends BodyBase
class_name BodyShooter

var is_shooting: bool = false
var _is_strafing_left: bool = false
var _is_strafing_right: bool = false

func _animate_moving(_velocity: Vector3) -> void:
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	_is_moving_backward = input.y > 0.3
	_is_strafing_left   = input.x < -0.3 and abs(input.y) <= 0.3
	_is_strafing_right  = input.x >  0.3 and abs(input.y) <= 0.3

	if _character:
		_character.is_moving_backward = _is_moving_backward

	var parent = get_parent()
	if parent:
		# reset rotation.y al valor correcto de la cámara
		if _character:
			parent.rotation.y = _character.model_rotation_y
		var is_diagonal = abs(input.x) > 0.3 and input.y < -0.3
		if is_diagonal:
			parent.rotation.z = lerp_angle(parent.rotation.z, deg_to_rad(10.0) * sign(input.x), 0.1)
		else:
			parent.rotation.z = lerp_angle(parent.rotation.z, 0.0, 0.1)

	if _is_strafing_left:
		if is_shooting:
			_play("LEFT_STRAFE_GUN_ANIM")
		else:
			_play("LEFT_STRAFE_ANIM")
		return

	if _is_strafing_right:
		if is_shooting:
			_play("RIGHT_STRAFE_GUN_ANIM")
		else:
			_play("RIGHT_STRAFE_ANIM")
		return

	if _is_moving_backward:
		if is_shooting:
			_play_reverse("RUN_GUN_ANIM")
		else:
			_play_reverse("RUN_ANIM")
			return
	var low_health = _character and _character.health / _character.max_health <= 0.15
	
	if is_shooting:
		_play("RUN_GUN_ANIM")
	else:
		if low_health:
			_play("INJURED_ANIM")
		else:
			_play("RUN_ANIM")

func _animate_idle() -> void:
	var parent = get_parent()
	if parent:
		parent.rotation.z = lerp_angle(parent.rotation.z, 0.0, 0.1)
		if _character:
			parent.rotation.y = _character.model_rotation_y
	if is_shooting:
		_play("GUNPLAY_ANIM", 2.0)
	else:
		_play("IDLE_ANIM")

func _animate_jumping() -> void:
	if not _character:
		return
	var parent = get_parent()
	if not parent:
		return

	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# si hay input hacia adelante, usar lean pequeño en Z en lugar de giro en Y
	if input.y < -0.3:
		parent.rotation.y = _character.model_rotation_y
		if abs(input.x) > 0.3:
			parent.rotation.z = lerp_angle(parent.rotation.z, deg_to_rad(10.0) * sign(input.x), 0.3)
		else:
			parent.rotation.z = lerp_angle(parent.rotation.z, 0.0, 0.3)
		return

	# sin W — calcular dirección del movimiento relativa al modelo
	var vel = Vector2(_character.velocity.x, _character.velocity.z)
	if vel.length() < 0.1:
		parent.rotation.y = _character.model_rotation_y
		return

	var move_angle = atan2(vel.x, vel.y)
	var model_angle = _character.model_rotation_y + PI
	var diff = angle_difference(model_angle, move_angle)

	if abs(diff) > deg_to_rad(30.0):
		parent.rotation.y = _character.model_rotation_y + deg_to_rad(90.0) * sign(diff)
	else:
		parent.rotation.y = _character.model_rotation_y

func play_jump_animation(jump_type: String = "Jump") -> void:
	super.play_jump_animation(jump_type)

func set_shooting(value: bool) -> void:
	is_shooting = value
