extends CharacterBody3D
class_name Character
 
# ──────────────────────────────────────────────────────────────────────
# CONSTANTES
# ──────────────────────────────────────────────────────────────────────
const NORMAL_SPEED        = 6.0
const SPRINT_SPEED        = 10.0
const JUMP_VELOCITY       = 4.5
 
const MOUSE_SENSITIVITY   = 0.005
const CAMERA_PITCH_MIN    = -40.0
const CAMERA_PITCH_MAX    = 60.0
const CAMERA_DISTANCE     = 2.5
 
const BULLET_SCENE        = preload("res://scenes/obj/bullet.tscn")
const SHOOT_COOLDOWN      = 0.15
const RESPAWN_TIME        = 10.0
const AMMO_MAX: int       = 50
const AMMO_RELOAD_TIME    = 10.0
 
# Distancia del raycast (úsalo si quieres limitar el alcance del disparo)
const SHOOT_MAX_DISTANCE  = 100.0
 
# ──────────────────────────────────────────────────────────────────────
# VARIABLES DE ESTADO
# ──────────────────────────────────────────────────────────────────────
var _reload_timer: float = 0.0
var _is_reloading: bool = false
var _shoot_timer: float = 0.0
var _is_respawning: bool = false
var ammo_current: int = 50
var ammo_reserve: int = 50
var _underdog_buff_applied: bool = false
var _damage_multiplier: float = 1.0   # se multiplica al daño que infligimos
 
# Touch input (móvil)
var _cam_touch_index: int = -1
var _cam_touch_last_pos: Vector2 = Vector2.ZERO
 
# Cámara
var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.0
var _shooting_mobile: bool = false
 
# Estado de juego
var health: float = 100.0
var max_health: float = 100.0
var _current_speed: float
var _respawn_point := Vector3(0, 5, 0)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
 
# Personaje
var character_data: CharacterData = null
var _model_instance: Node3D = null
 
# ──────────────────────────────────────────────────────────────────────
# REFERENCIAS A NODOS
# ──────────────────────────────────────────────────────────────────────
@onready var nickname: Label3D = $PlayerNick/Nickname
@onready var _raycast: RayCast3D = $SpringArmOffset/SpringArm3D/Camera3D/RayCast3D
@onready var _spring_arm_offset: Node3D = $SpringArmOffset
@onready var _multiplayer_sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
 
# CAMBIO: Esta referencia al crosshair se busca de forma más segura ahora.
# Se inicializa en _ready() en vez de @onready para evitar que falle
# si la escena aún no está completamente lista.
var _crosshair_label: Label = null
 
@export_category("Objects")
@export var _body: Node3D = null
@export var _muzzle: Node3D = null
 
# ──────────────────────────────────────────────────────────────────────
# PROPIEDADES SINCRONIZADAS
# Estas variables se replican automáticamente vía MultiplayerSynchronizer
# cuando cambian su valor. Los setters propagan efectos visuales en
# clientes remotos.
# ──────────────────────────────────────────────────────────────────────
var current_animation: String = "IDLE_ANIM":
	set(value):
		current_animation = value
		_apply_remote_animation(value)
 
var model_rotation_y: float = 0.0:
	set(value):
		model_rotation_y = value
		if not is_multiplayer_authority() and _model_instance:
			_model_instance.rotation.y = value
 
var is_moving_backward: bool = false:
	set(value):
		is_moving_backward = value
		if not is_multiplayer_authority() and _body:
			_body._is_moving_backward = value
 
var is_dead_synced: bool = false:
	set(value):
		is_dead_synced = value
		if _body:
			_body._is_dead = value
 
# ──────────────────────────────────────────────────────────────────────
# LIFECYCLE
# ──────────────────────────────────────────────────────────────────────
 
func _enter_tree() -> void:
	# La autoridad del personaje es el peer dueño (su nombre = peer_id).
	# Esto se mantiene igual: cliente-autoritativo, OK para tu caso.
	set_multiplayer_authority(str(name).to_int())
	$SpringArmOffset/SpringArm3D/Camera3D.current = is_multiplayer_authority()
 
 
func _ready() -> void:
	add_to_group("players")
	$PlayerNick.visible = not is_multiplayer_authority()
 
	# CAMBIO: Buscar el crosshair de forma segura. Si no existe (porque
	# la escena cambió o se está cargando), no rompe el juego.
	var current_scene = get_tree().get_current_scene()
	if current_scene and current_scene.has_node("CanvasLayer/CenterContainer/Label"):
		_crosshair_label = current_scene.get_node("CanvasLayer/CenterContainer/Label")
 
	# CAMBIO: La configuración del MultiplayerSynchronizer debería estar
	# en la escena (.tscn), pero si la dejas en código, aquí está más limpia.
	# Idealmente: borrar este bloque y configurar las propiedades en el editor.
	_setup_replication_config()
 
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_camera_yaw = PI
		_apply_camera_rotation()
		$SpringArmOffset/SpringArm3D.spring_length = CAMERA_DISTANCE
	
	GameManager.match_started.connect(_on_match_started)

func _on_match_started() -> void:
	# Solo el servidor aplica el buff (es autoritativo de la salud)
	if not multiplayer.is_server():
		return
 
	var my_id := str(name).to_int()
	if GameManager.should_apply_underdog_buff(my_id):
		_apply_underdog_buff.rpc(true)
	else:
		_apply_underdog_buff.rpc(false)
 
 
func _setup_replication_config() -> void:
	# NOTA: Esto es funcional pero NO es la mejor práctica.
	# Lo recomendado es configurar el MultiplayerSynchronizer en el .tscn
	# desde el editor, donde se inicializa antes y es visualmente claro.
	# Lo dejo aquí porque ya lo tenías así; cuando puedas, migra al editor.
	if not _multiplayer_sync:
		push_warning("MultiplayerSynchronizer no encontrado en Player")
		return
 
	var config := SceneReplicationConfig.new()
	_multiplayer_sync.replication_config = config
	config.add_property(".:position")
	config.add_property(".:rotation")
	config.add_property(".:current_animation")
	config.add_property(".:model_rotation_y")
	config.add_property(".:is_moving_backward")
	config.add_property(".:is_dead_synced")
 
 
# ──────────────────────────────────────────────────────────────────────
# INPUT
# ──────────────────────────────────────────────────────────────────────
 
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
 
	var hud = get_tree().get_current_scene()._hud
	if not hud:
		return
 
	# Touch (móvil): identificar qué dedo controla la cámara
	if event is InputEventScreenTouch:
		if event.pressed and _cam_touch_index == -1:
			var dpad = hud.get_dpad()
			var ab = hud.get_action_buttons()
			var active := []
			if dpad: active += dpad.get_active_touches()
			if ab:   active += ab.get_active_touches()
			if not event.index in active:
				_cam_touch_index = event.index
				_cam_touch_last_pos = event.position
		elif not event.pressed and event.index == _cam_touch_index:
			_cam_touch_index = -1
 
	elif event is InputEventScreenDrag and event.index == _cam_touch_index:
		var delta = event.position - _cam_touch_last_pos
		_cam_touch_last_pos = event.position
		_handle_camera_input(delta.x, delta.y)
 
	# Mouse (PC)
	elif event is InputEventMouseMotion:
		_handle_camera_input(event.relative.x, event.relative.y)
 
 
# CAMBIO: Extraído a función helper para evitar duplicación del código
# de rotación de cámara entre touch y mouse.
func _handle_camera_input(delta_x: float, delta_y: float) -> void:
	_camera_yaw -= delta_x * MOUSE_SENSITIVITY
	_camera_pitch -= delta_y * MOUSE_SENSITIVITY
	_camera_pitch = clamp(
		_camera_pitch,
		deg_to_rad(CAMERA_PITCH_MIN),
		deg_to_rad(CAMERA_PITCH_MAX)
	)
	_apply_camera_rotation()
	if _model_instance:
		_model_instance.rotation.y = _camera_yaw - PI
		model_rotation_y = _camera_yaw - PI
 
 
# ──────────────────────────────────────────────────────────────────────
# FÍSICA
# ──────────────────────────────────────────────────────────────────────
 
func _physics_process(delta: float) -> void:
	# Tick de recarga: corre en todos los clientes que tienen autoridad
	# sobre su personaje. OK porque la recarga es local en cliente-autoritativo.
	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_is_reloading = false
			ammo_current = AMMO_MAX
			ammo_reserve = AMMO_MAX
 
	if not multiplayer.has_multiplayer_peer(): return
	if not is_multiplayer_authority(): return
 
	# CAMBIO: Chequeo del chat más defensivo. Si la escena no tiene el método,
	# no crashea.
	if _is_chat_blocking_input():
		freeze()
		return
 
	if is_dead():
		return
 
	# Salto y gravedad
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			if _body:
				if velocity.length() > 0.1:
					_body.play_jump_animation("Jump2")
				else:
					_body.play_jump_animation("Jump")
	else:
		velocity.y -= gravity * delta
 
	_move()
	move_and_slide()
 
	# Disparo
	_shoot_timer -= delta
	if _body:
		_body.animate(velocity)
		var should_shoot = _get_shoot_input()
		if should_shoot and not _is_reloading:
			_body.set_shooting(true)
			if _shoot_timer <= 0.0:
				_shoot()
				_shoot_timer = SHOOT_COOLDOWN
		else:
			_body.set_shooting(false)
 
	_update_crosshair()
	model_rotation_y = _camera_yaw - PI
 
 
func _process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer(): return
	if not is_multiplayer_authority(): return
	_check_fall_and_respawn()
 
 
# CAMBIO: helpers extraídos para que _physics_process sea más legible
func _is_chat_blocking_input() -> bool:
	var current_scene = get_tree().get_current_scene()
	if current_scene and current_scene.has_method("is_chat_visible"):
		return current_scene.is_chat_visible()
	return false
 
 
func _get_shoot_input() -> bool:
	if OS.has_feature("mobile"):
		return _shooting_mobile
	return Input.is_action_pressed("shoot")
 
 
func freeze() -> void:
	velocity.x = 0
	velocity.z = 0
	_current_speed = 0
	if _body:
		_body.animate(Vector3.ZERO)
 
 
func _move() -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_basis = Basis(Vector3.UP, _camera_yaw)
	var direction = (cam_basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()
 
	_current_speed = SPRINT_SPEED if Input.is_action_pressed("shift") else NORMAL_SPEED
 
	if direction.length() > 0.1:
		velocity.x = direction.x * _current_speed
		velocity.z = direction.z * _current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, _current_speed)
		velocity.z = move_toward(velocity.z, 0, _current_speed)
 
 
func _apply_camera_rotation() -> void:
	_spring_arm_offset.rotation.y = _camera_yaw
	_spring_arm_offset.get_node("SpringArm3D").rotation.x = _camera_pitch
 
 
func _check_fall_and_respawn() -> void:
	if global_transform.origin.y < -15.0:
		_respawn_local()
 
 
func _respawn_local() -> void:
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO
 
 
# ──────────────────────────────────────────────────────────────────────
# RED — RPCs
# ──────────────────────────────────────────────────────────────────────
 
# CAMBIO: Validación básica añadida. Solo el dueño legítimo del personaje
# puede cambiar su nick. Cuesta 1 línea y previene errores tontos.
@rpc("any_peer", "reliable")
func change_nick(new_nick: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != str(name).to_int() and sender_id != 1:
		return  # solo el dueño o el server pueden cambiar el nick
	if nickname:
		nickname.text = new_nick
 
func set_character_by_id_local(character_id: String) -> void:
	print("[Player] set_character_by_id_local | nodo='%s' | id='%s'" % [name, character_id])
	var data := _load_character_resource(character_id)
	if data == null:
		push_error("[Player] recurso null para: '%s'" % character_id)
		return
	character_data = data
	_load_model(data)

func _load_character_resource(character_id: String) -> CharacterData:
	var paths := {
		"amy":       "res://assets/characters/team_a/Amy/amy.tres",
		"michelle":  "res://assets/characters/team_a/Michelle/michelle.tres",
		"ortiz":     "res://assets/characters/team_a/Ortiz/ortiz.tres",
		"big_vegas": "res://assets/characters/team_b/Big Vegas/big_vegas.tres",
		"kaya":      "res://assets/characters/team_a/Kaya/kaya.tres",
		"mousey":    "res://assets/characters/team_b/Mousey/mousey.tres"
	}
	if character_id in paths:
		return load(paths[character_id])
	return null
	
func set_character(data: CharacterData) -> void:
	character_data = data
	_load_model(data)
 
func _load_model(data: CharacterData) -> void:
	print("[Player] _load_model | nodo='%s' | model_scene=%s" % [
		name, str(data.model_scene)
	])
	if _model_instance:
		_model_instance.queue_free()
	_model_instance = data.model_scene.instantiate()
	if _model_instance == null:
		push_error("[Player] model_scene.instantiate() devolvió null")
		return
	add_child(_model_instance)
	print("[Player] modelo agregado como hijo OK | hijos=%d" % get_child_count())
 
	var body_script = load("res://scripts/body_shooter.gd")
	if data.character_type == 1:
		body_script = load("res://scripts/body_melee.gd")
 
	var body_node = Node3D.new()
	body_node.name = "Body"
	body_node.set_script(body_script)
	_model_instance.add_child(body_node)
	_body = body_node
	_body._character = self
	_body.animation_player = _model_instance.get_node("AnimationPlayer")
 
	# Deshabilitar animación de root motion en hips (anti-deslizamiento)
	var anim_player = _body.animation_player
	for anim_name in anim_player.get_animation_list():
		var anim = anim_player.get_animation(anim_name)
		for i in range(anim.get_track_count()):
			var path = str(anim.track_get_path(i))
			if path.contains("mixamorig_Hips") and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
				anim.track_set_enabled(i, false)
 
	_body.animation_player.play("IDLE_ANIM")
 
 
func is_dead() -> bool:
	return health <= 0.0
 
 
func is_low_health() -> bool:
	return health / max_health <= 0.25
 
 
# ──────────────────────────────────────────────────────────────────────
# DAÑO — server-authoritative (esto YA estaba bien)
# ──────────────────────────────────────────────────────────────────────
 
@rpc("any_peer", "reliable")
func take_damage(amount: float, attacker_id: int) -> void:
	# Solo el server procesa daño. Los clientes solo lo solicitan.
	if not multiplayer.is_server():
		return
	if is_dead() or _is_respawning:
		return
 
	health = max(0.0, health - amount)
	sync_health.rpc(health)
 
	if health <= 0.0:
		_is_respawning = true
		_play_death_local()
		get_tree().current_scene.broadcast_death.rpc(name)
 
		# CAMBIO 4: Reportar la muerte al GameManager
		var victim_id := str(name).to_int()
		GameManager.report_kill(victim_id, attacker_id)
 
		# Solo respawnear si la partida sigue en progreso
		await get_tree().create_timer(RESPAWN_TIME).timeout
		if not is_instance_valid(self):
			return
		if not is_inside_tree():
			return
		# CAMBIO 4b: No respawnear si la partida terminó
		if GameManager.match_state == GameManager.MatchState.ENDED:
			return
		_is_respawning = false
		get_tree().current_scene.broadcast_respawn.rpc(name)
		do_respawn()
	else:
		on_hit.rpc()
 
 
 
@rpc("any_peer", "call_local", "reliable")
func sync_health(new_health: float) -> void:
	health = new_health
 
 
@rpc("any_peer", "call_local", "reliable")
func on_hit() -> void:
	if _body:
		_body.play_injured_animation()

@rpc("authority", "reliable", "call_local")
func _apply_underdog_buff(enable: bool) -> void:
	if enable and not _underdog_buff_applied:
		max_health *= GameManager.UNDERDOG_HEALTH_MULTIPLIER
		health = max_health
		_damage_multiplier = GameManager.UNDERDOG_DAMAGE_MULTIPLIER
		_underdog_buff_applied = true
		print("[Player] Buff de desventaja aplicado a '%s'" % name)
 
 
@rpc("any_peer", "call_local", "reliable")
func on_death(_killer_id: int) -> void:
	_play_death_local()
 
 
@rpc("any_peer", "call_local", "reliable")
func do_respawn() -> void:
	_is_respawning = false
	health = max_health
	is_dead_synced = false
	global_transform.origin = _respawn_point
	velocity = Vector3.ZERO
	$CollisionShape3D.disabled = false
	if _body:
		_body._is_dead = false
		_body.reset_death()
		_body.animation_player.speed_scale = 1.0
		_body.animation_player.play("IDLE_JUMP_ANIM")
 
 
# ──────────────────────────────────────────────────────────────────────
# DISPARO
# ──────────────────────────────────────────────────────────────────────
 
func _shoot() -> void:
	if not is_multiplayer_authority():
		return
	if ammo_current <= 0:
		return
 
	ammo_current -= 1
	if ammo_current <= 0 and not _is_reloading:
		_is_reloading = true
		_reload_timer = AMMO_RELOAD_TIME
 
	# Determinar punto de impacto y target
	var impact_point: Vector3
	var hit_target: Character = null
 
	if _raycast.is_colliding():
		impact_point = _raycast.get_collision_point()
		var hit = _raycast.get_collider()
		var target = hit if hit is Character else hit.get_parent()
		if target is Character and not target.is_dead():
			hit_target = target
	else:
		impact_point = _raycast.global_position + \
			_raycast.target_position.length() * (_raycast.global_basis * Vector3(0, 0, -1))
 
	# Spawn de bala visual (todos los clientes la verán por replicación de la escena)
	var muzzle_pos = _muzzle.global_position if _muzzle else global_position + Vector3(0, 1.2, 0)
	var bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.setup(muzzle_pos, impact_point)
 
	# Aplicar daño (vía server)
	var damage = (character_data.damage if character_data else 25.0) * _damage_multiplier
	if hit_target:
		if multiplayer.is_server():
			hit_target.take_damage(damage, multiplayer.get_unique_id())
		else:
			hit_target.take_damage.rpc_id(1, damage, multiplayer.get_unique_id())
 
 
# ──────────────────────────────────────────────────────────────────────
# ANIMACIONES
# ──────────────────────────────────────────────────────────────────────
 
func _apply_remote_animation(anim_name: String) -> void:
	if is_multiplayer_authority(): return
	if not _body or not _body.animation_player: return
	if _body._is_dead: return  # CAMBIO: redundancia eliminada (estaba duplicado)
 
	if anim_name.begins_with("REVERSE_"):
		var real_name = anim_name.replace("REVERSE_", "")
		_body.animation_player.speed_scale = 1.0
		_body.animation_player.play_backwards(real_name)
	else:
		_body.animation_player.speed_scale = 1.0
		if _body.animation_player.current_animation != anim_name:
			_body.animation_player.play(anim_name)
 
 
func _play_death_local() -> void:
	health = 0.0
	is_dead_synced = true
	$CollisionShape3D.disabled = true
	if _body:
		_body._is_dead = true
		_body.play_death_animation()
 
 
# ──────────────────────────────────────────────────────────────────────
# CROSSHAIR
# ──────────────────────────────────────────────────────────────────────
 
func _update_crosshair() -> void:
	if not is_multiplayer_authority():
		return
	if _crosshair_label == null:
		return
 
	if _is_reloading:
		_crosshair_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		return
 
	if _raycast.is_colliding():
		var hit = _raycast.get_collider()
		var target = hit if hit is Character else hit.get_parent()
		if target is Character and not target.is_dead():
			_crosshair_label.add_theme_color_override("font_color", Color.WHITE)
			return
 
	_crosshair_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
