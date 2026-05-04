extends Node
const CONFIG_PATH := "user://preferences.cfg"
const SECTION_PLAYER := "player"
const SECTION_NETWORK := "network"
 
var _config: ConfigFile = null
 
# Valores por defecto (se usan si no existe el archivo aún)
const DEFAULTS := {
	"nickname": "",
	"last_character": "amy",
	"last_address": ""
}
 
 
func _ready() -> void:
	_config = ConfigFile.new()
	_load()
 
 
func _load() -> void:
	var err := _config.load(CONFIG_PATH)
	if err != OK:
		# Archivo no existe todavía. Es la primera vez que se ejecuta el juego.
		print("[UserPreferences] No existen preferencias previas, usando defaults")
 
 
func _save() -> void:
	var err := _config.save(CONFIG_PATH)
	if err != OK:
		push_error("[UserPreferences] Error al guardar preferencias: %s" % err)
 
 
func get_nickname() -> String:
	return _config.get_value(SECTION_PLAYER, "nickname", DEFAULTS["nickname"])
 
 
func set_nickname(nick: String) -> void:
	# Sanitización suave: trim y limitar longitud
	nick = nick.strip_edges().substr(0, 20)
	if nick.is_empty():
		return
	_config.set_value(SECTION_PLAYER, "nickname", nick)
	_save()
	print("[UserPreferences] Nickname guardado: %s" % nick)
 
func get_last_character() -> String:
	return _config.get_value(SECTION_PLAYER, "last_character", DEFAULTS["last_character"])
 
 
func set_last_character(character_id: String) -> void:
	if character_id.is_empty():
		return
	_config.set_value(SECTION_PLAYER, "last_character", character_id)
	_save()
 
func get_last_address() -> String:
	return _config.get_value(SECTION_NETWORK, "last_address", DEFAULTS["last_address"])
 
 
func set_last_address(address: String) -> void:
	address = address.strip_edges()
	if address.is_empty():
		return
	_config.set_value(SECTION_NETWORK, "last_address", address)
	_save()
 
func clear_all() -> void:
	_config.clear()
	_save()
	print("[UserPreferences] Todas las preferencias borradas")
