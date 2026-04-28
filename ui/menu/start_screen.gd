extends Control

signal proceed


func on_screen_opened() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		proceed.emit()
	elif event is InputEventMouseButton and event.pressed:
		proceed.emit()
