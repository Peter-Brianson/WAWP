extends Control

signal controls_requested
signal glossary_requested
signal back_requested

@onready var controls_button: Button = $CenterContainer/VBoxContainer/ControlsButton
@onready var glossary_button: Button = $CenterContainer/VBoxContainer/GlossaryButton
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	controls_button.pressed.connect(_on_controls_pressed)
	glossary_button.pressed.connect(_on_glossary_pressed)
	back_button.pressed.connect(_on_back_pressed)


func on_screen_opened() -> void:
	controls_button.grab_focus()


func _on_controls_pressed() -> void:
	controls_requested.emit()


func _on_glossary_pressed() -> void:
	glossary_requested.emit()


func _on_back_pressed() -> void:
	back_requested.emit()
