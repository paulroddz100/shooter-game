extends BodyBase
class_name BodyMelee

var is_punching: bool = false

func _animate_moving(_velocity: Vector3) -> void:
	apply_rotation(_velocity)
	
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input.y > 0.3:
		_play_reverse("RUN_ANIM")
		return
	
	_play("RUN_ANIM")

func _animate_idle() -> void:
	if is_punching:
		_play("PUNCH_ANIM")
	else:
		_play("IDLE_ANIM")

func play_jump_animation(jump_type: String = "Jump") -> void:
	match jump_type:
		"Jump":
			if is_punching:
				_play("PUNCH_JUMP_ANIM")
			else:
				_play("IDLE_JUMP_ANIM")
		"Jump2": _play("RUN_JUMP_ANIM")

func set_punching(value: bool) -> void:
	is_punching = value
