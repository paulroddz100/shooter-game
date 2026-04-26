extends Control
class_name MainMenuUI

signal quit_pressed
signal open_character_select(nickname: String, address: String, is_host: bool)

@onready var nick_input: LineEdit = $MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $MainContainer/MainMenu/Option3/AddressInput

func _ready():
	pass

func _on_host_pressed():
	var nickname = nick_input.text.strip_edges()
	open_character_select.emit(nickname, "", true)

func _on_join_pressed():
	var nickname = nick_input.text.strip_edges()
	var address = address_input.text.strip_edges()
	open_character_select.emit(nickname, address, false)

func _on_quit_pressed():
	quit_pressed.emit()

func show_menu():
	show()

func hide_menu():
	hide()

func is_menu_visible() -> bool:
	return visible

func get_nickname() -> String:
	return nick_input.text.strip_edges()

func get_address() -> String:
	return address_input.text.strip_edges()
