extends Node3D

const SPEED = 100.0
const MAX_DISTANCE = 100.0

var direction: Vector3 = Vector3.ZERO
var start_position: Vector3 = Vector3.ZERO
var color: Color = Color.WHITE
var _travelled: float = 0.0
var target_point: Vector3 = Vector3.ZERO

func setup(from: Vector3, to: Vector3, bullet_color: Color = Color.WHITE) -> void:
	start_position = from
	global_position = from
	target_point = to
	color = bullet_color
	direction = (to - from).normalized()
	look_at(to, Vector3.UP)
	_setup_visuals()

func _setup_visuals() -> void:
	# cuerpo de la bala — cápsula alargada
	var mesh_instance = $MeshInstance3D
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.03
	capsule.height = 0.4
	mesh_instance.mesh = capsule
	mesh_instance.rotation_degrees.x = 90.0

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh_instance.material_override = mat

	# estela de partículas
	var particles = $GPUParticles3D
	particles.amount = 20
	particles.lifetime = 0.05
	particles.explosiveness = 0.0
	particles.emitting = true

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0, 0, 1)
	particle_mat.spread = 5.0
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 4.0
	particle_mat.scale_min = 0.02
	particle_mat.scale_max = 0.05
	particle_mat.color = color
	particles.process_material = particle_mat

	var particle_mesh = QuadMesh.new()
	particle_mesh.size = Vector2(0.05, 0.05)
	particles.draw_pass_1 = particle_mesh

func _process(delta: float) -> void:
	var move = direction * SPEED * delta
	global_position += move
	_travelled += move.length()

	if _travelled >= global_position.distance_to(target_point) or _travelled >= MAX_DISTANCE:
		_on_impact()

func _on_impact() -> void:
	# detener movimiento y partículas
	set_process(false)
	$GPUParticles3D.emitting = false
	$MeshInstance3D.visible = false
	# esperar a que las partículas terminen y destruir
	await get_tree().create_timer(0.1).timeout
	queue_free()
