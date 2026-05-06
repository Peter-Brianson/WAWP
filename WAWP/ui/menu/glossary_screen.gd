extends Control

signal back_requested

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func on_screen_opened() -> void:
	back_button.grab_focus()


func _on_back_pressed() -> void:
	back_requested.emit()
