extends Node

@onready var book_interactable: BookInteractable = $World/InteractionPoints/BookInteractable
@onready var book_ui: Control = $CanvasLayer/BookUI


func _ready() -> void:
	if book_interactable != null:
		book_interactable.open_book_requested.connect(_on_open_book_requested)

	if book_ui != null:
		book_ui.visible = false


func _on_open_book_requested(book: BookInteractable) -> void:
	open_book_ui()


func open_book_ui() -> void:
	if book_interactable != null:
		book_interactable.set_enabled(false)

	if book_ui != null:
		book_ui.visible = true


func close_book_ui() -> void:
	if book_ui != null:
		book_ui.visible = false

	if book_interactable != null:
		book_interactable.set_enabled(true)
