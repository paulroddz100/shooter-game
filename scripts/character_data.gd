extends Resource
class_name CharacterData

@export var character_name: String
@export var team: int           # 0 = team_a, 1 = team_b
@export var character_type: int # 0 = shooter, 1 = melee
@export var model_scene: PackedScene
@export var max_health: float = 100.0
@export var move_speed: float = 6.0
@export var sprint_speed: float = 10.0
