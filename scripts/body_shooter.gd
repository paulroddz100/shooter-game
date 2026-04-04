extends BodyBase
class_name BodyShooter

var is_shooting: bool = false

func _animate_moving(_velocity: Vector3) -> void:
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	_is_moving_backward = input.y > 0.3
	
	apply_rotation(_velocity)
	
	if _is_moving_backward:
		if is_shooting:
			_play_reverse("RUN_GUN_ANIM")
		else:
			_play_reverse("RUN_ANIM")
		return
	
	if is_shooting:
		_play("RUN_GUN_ANIM")
	else:
		_play("RUN_ANIM")

func _animate_idle() -> void:
	if is_shooting:
		_play("GUNPLAY_ANIM")
	else:
		_play("IDLE_ANIM")

func set_shooting(value: bool) -> void:
	is_shooting = value
