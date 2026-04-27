extends Control
class_name GameModeSelectUI

signal mode_confirmed(mode_id: String)

@onready var background       : ColorRect   = $Background
@onready var banner           : TextureRect = $CenterContainer/BannerRow/Banner
@onready var prev_btn         : Button      = $CenterContainer/BannerRow/PrevButton
@onready var next_btn         : Button      = $CenterContainer/BannerRow/NextButton
@onready var mode_title       : Label       = $CenterContainer/ModeTitle
@onready var mode_description : Label       = $CenterContainer/ModeDescription
@onready var start_btn        : Button      = $StartButton

const MODES := [
	{
		"id":          "team_deathmatch",
		"title":       "Team Deathmatch",
		"description": "El primer equipo en acumular 20 bajas ganará la partida.\n¡Coordínate con tu equipo y elimina al enemigo!",
		"banner":      "res://assets/ui/BANNER1.png"
	},
	{
		"id":          "time_battle",
		"title":       "Batalla por Tiempo",
		"description": "Tienes 10 minutos para conseguir la mayor cantidad de bajas.\nEl equipo con más eliminaciones al terminar el tiempo ganará.",
		"banner":      "res://assets/ui/BANNER2.png"
	}
]

var _current_index : int = 0

func _ready() -> void:
	prev_btn.pressed.connect(_on_prev_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	_update_display()

func _on_prev_pressed() -> void:
	_current_index = (_current_index - 1 + MODES.size()) % MODES.size()
	_update_display()

func _on_next_pressed() -> void:
	_current_index = (_current_index + 1) % MODES.size()
	_update_display()

func _update_display() -> void:
	var mode : Dictionary = MODES[_current_index]
	mode_title.text       = mode["title"]
	mode_description.text = mode["description"]

	# Actualizar flechas — con solo 2 modos siempre están activas
	prev_btn.disabled = false
	next_btn.disabled = false

	# Cargar banner si existe
	if ResourceLoader.exists(mode["banner"]):
		banner.texture = load(mode["banner"])
	else:
		banner.texture = null  # placeholder hasta tener las imágenes

func _on_start_pressed() -> void:
	var mode_id : String = MODES[_current_index]["id"]
	mode_confirmed.emit(mode_id)
