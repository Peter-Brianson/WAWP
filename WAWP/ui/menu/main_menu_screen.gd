extends Control

signal new_game_requested
signal continue_requested
signal options_requested
signal quit_requested

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var play_branch: VBoxContainer = $CenterContainer/VBoxContainer/PlayBranch
@onready var new_game_button: Button = $CenterContainer/VBoxContainer/PlayBranch/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/PlayBranch/ContinueButton
@onready var branch_back_button: Button = $CenterContainer/VBoxContainer/PlayBranch/BranchBackButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	branch_back_button.pressed.connect(_on_branch_back_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	play_branch.visible = false


func on_screen_opened() -> void:
	play_branch.visible = false
	play_button.grab_focus()


func _on_play_pressed() -> void:
	play_branch.visible = true
	continue_button.disabled = not SaveManager.has_any_save()


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _on_continue_pressed() -> void:
	continue_requested.emit()


func _on_branch_back_pressed() -> void:
	play_branch.visible = false
	play_button.grab_focus()


func _on_options_pressed() -> void:
	options_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
