extends Control
class_name MainMenuUI
 
signal quit_pressed
signal open_character_select(nickname: String, address: String, is_host: bool)
 
@onready var nick_input: LineEdit = $MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $MainContainer/MainMenu/Option3/AddressInput
 
 
func _ready() -> void:
	# Cargar preferencias guardadas para autocompletar campos
	_load_saved_preferences()
 
 
func _load_saved_preferences() -> void:
	var saved_nick := UserPreferences.get_nickname()
	if not saved_nick.is_empty():
		nick_input.text = saved_nick
 
	var saved_address := UserPreferences.get_last_address()
	if not saved_address.is_empty():
		address_input.text = saved_address
 
 
func _on_host_pressed() -> void:
	var nickname := nick_input.text.strip_edges()
	# Guardar nickname para la próxima vez
	UserPreferences.set_nickname(nickname)
	open_character_select.emit(nickname, "", true)
 
 
func _on_join_pressed() -> void:
	var nickname := nick_input.text.strip_edges()
	var address := address_input.text.strip_edges()
	# Guardar ambos para la próxima vez
	UserPreferences.set_nickname(nickname)
	UserPreferences.set_last_address(address)
	open_character_select.emit(nickname, address, false)
 
 
func _on_quit_pressed() -> void:
	quit_pressed.emit()
 
 
func show_menu() -> void:
	show()
 
 
func hide_menu() -> void:
	hide()
 
 
func is_menu_visible() -> bool:
	return visible
 
 
func get_nickname() -> String:
	return nick_input.text.strip_edges()
 
 
func get_address() -> String:
	return address_input.text.strip_edges()
