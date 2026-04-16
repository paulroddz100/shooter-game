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

	if _is_strafing_left:
		_play("LEFT_STRAFE_GUN_ANIM") if is_shooting else _play("LEFT_STRAFE_ANIM")
		return
	
	if _is_strafing_right:
		_play("RIGHT_STRAFE_GUN_ANIM") if is_shooting else _play("RIGHT_STRAFE_ANIM")
		return

	if _is_moving_backward:
		_play_reverse("RUN_GUN_ANIM") if is_shooting else _play_reverse("RUN_ANIM")
		return

	if is_shooting:
		_play("RUN_GUN_ANIM")
	else:
		_play("RUN_ANIM")

func _animate_idle() -> void:
	if is_shooting:
		_play("GUNPLAY_ANIM", 2.0)
	else:
		_play("IDLE_ANIM")

func set_shooting(value: bool) -> void:
	is_shooting = value
