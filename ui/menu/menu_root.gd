extends Control

const GAME_SCENE_PATH := "res://scenes/main/game.tscn"

@onready var screens: Control = $Screens
@onready var intro_screen: Control = $Screens/IntroScreen
@onready var start_screen: Control = $Screens/StartScreen
@onready var main_menu_screen: Control = $Screens/MainMenuScreen
@onready var save_list_screen: Control = $Screens/SaveListScreen
@onready var options_screen: Control = $Screens/OptionsScreen
@onready var controls_screen: Control = $Screens/ControlsScreen
@onready var glossary_screen: Control = $Screens/GlossaryScreen


func _ready() -> void:
	show_screen(intro_screen)

	intro_screen.finished.connect(_on_intro_finished)
	start_screen.proceed.connect(_on_start_proceed)

	main_menu_screen.new_game_requested.connect(_on_new_game_requested)
	main_menu_screen.continue_requested.connect(_on_continue_requested)
	main_menu_screen.options_requested.connect(_on_options_requested)
	main_menu_screen.quit_requested.connect(_on_quit_requested)

	save_list_screen.back_requested.connect(_on_saves_back_requested)
	save_list_screen.slot_chosen.connect(_on_save_slot_chosen)

	options_screen.back_requested.connect(_on_options_back_requested)
	options_screen.controls_requested.connect(_on_controls_requested)
	options_screen.glossary_requested.connect(_on_glossary_requested)

	controls_screen.back_requested.connect(_on_controls_back_requested)
	glossary_screen.back_requested.connect(_on_glossary_back_requested)


func show_screen(target: Control) -> void:
	for child in screens.get_children():
		if child is Control:
			child.visible = (child == target)
			if child == target and child.has_method("on_screen_opened"):
				child.on_screen_opened()


func _on_intro_finished() -> void:
	show_screen(start_screen)


func _on_start_proceed() -> void:
	show_screen(main_menu_screen)


func _on_new_game_requested() -> void:
	SaveManager.start_new_game()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_continue_requested() -> void:
	save_list_screen.refresh_list()
	show_screen(save_list_screen)


func _on_options_requested() -> void:
	show_screen(options_screen)


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_saves_back_requested() -> void:
	show_screen(main_menu_screen)


func _on_save_slot_chosen(slot_id: String) -> void:
	SaveManager.continue_from_slot(slot_id)
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_options_back_requested() -> void:
	show_screen(main_menu_screen)


func _on_controls_requested() -> void:
	show_screen(controls_screen)


func _on_glossary_requested() -> void:
	show_screen(glossary_screen)


func _on_controls_back_requested() -> void:
	show_screen(options_screen)


func _on_glossary_back_requested() -> void:
	show_screen(options_screen)
