extends Node3D
class_name BodyBase

const LERP_VELOCITY: float = 0.15
const LOW_HEALTH_THRESHOLD: float = 0.25

var _is_playing_reverse: bool = false
var _is_moving_backward: bool = false
var _is_dead: bool = false

@export_category("Objects")
@export var _character: CharacterBody3D = null
@export var animation_player: AnimationPlayer = null

func apply_camera_rotation(yaw: float) -> void:
	var parent = get_parent()
	if not parent:
		return
	parent.rotation.y = yaw - PI
	if _character:
		_character.model_rotation_y = yaw - PI

func animate(_velocity: Vector3) -> void:
	if _is_dead:
		return
	if not _character.is_on_floor():
		return
	if _velocity.length() > 0.1:
		_animate_moving(_velocity)
		return
	_animate_idle()

func play_death_animation() -> void:
	_is_dead = true
	_play("DEATH_ANIM")

func play_injured_animation() -> void:
	if _is_dead:
		return
	_play("INJURED_ANIM")

func play_jump_animation(jump_type: String = "Jump") -> void:
	match jump_type:
		"Jump":
			_play("IDLE_JUMP_ANIM")
		"Jump2":
			if _is_moving_backward:
				_play_reverse("RUN_JUMP_ANIM")
			else:
				_play("RUN_JUMP_ANIM")

func reset_death() -> void:
	_is_dead = false

func _animate_moving(_velocity: Vector3) -> void:
	_play("RUN_ANIM")

func _animate_idle() -> void:
	_play("IDLE_ANIM")

func _play(anim_name: String, speed: float = 1.0) -> void:
	if animation_player:
		if animation_player.current_animation != anim_name:
			animation_player.speed_scale = speed
			_is_playing_reverse = false
			animation_player.play(anim_name)
			if _character:
				_character.current_animation = anim_name

func _play_reverse(anim_name: String) -> void:
	if animation_player:
		if not _is_playing_reverse or animation_player.current_animation != anim_name:
			animation_player.speed_scale = 1.0
			_is_playing_reverse = true
			animation_player.play_backwards(anim_name)
			if _character:
				_character.current_animation = "REVERSE_" + anim_name
