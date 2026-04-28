extends Control

signal finished

@export var auto_advance_seconds: float = 2.5
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)


func on_screen_opened() -> void:
	timer.start(auto_advance_seconds)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		finished.emit()
	elif event is InputEventMouseButton and event.pressed:
		finished.emit()


func _on_timer_timeout() -> void:
	finished.emit()
