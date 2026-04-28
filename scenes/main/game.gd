extends Node

@onready var book_interactable: BookInteractable = $World/InteractionPoints/BookInteractable
@onready var book_ui: BookUI = $CanvasLayer/BookUI


func _ready() -> void:
	if book_interactable != null:
		book_interactable.open_requested.connect(_on_book_open_requested)

	if book_ui != null:
		book_ui.closed.connect(_on_book_ui_closed)
		book_ui.game_selected.connect(_on_book_game_selected)


func _on_book_open_requested(book: BookInteractable) -> void:
	if book_interactable != null:
		book_interactable.set_enabled(false)

	var available_games: Array[StringName] = [
		&"war",
		&"go_fish",
		&"old_maid"
	]

	var played_games: Array[StringName] = []

	var preference_notes := {
		&"war": [
			"[b]Bear[/b]: Finally, a simple one.",
			"[b]Fox[/b]: This barely counts as strategy."
		],
		&"go_fish": [
			"[b]Fox[/b]: I like asking suspicious questions.",
			"[b]Raccoon[/b]: Can I ask for cards I already have?"
		],
		&"old_maid": [
			"[b]Owl[/b]: A proper deduction exercise.",
			"[b]Bear[/b]: I do not trust the queen."
		]
	}

	book_ui.open_book(
		available_games,
		played_games,
		preference_notes,
		0,
		0
	)


func _on_book_ui_closed() -> void:
	if book_interactable != null:
		book_interactable.set_enabled(true)


func _on_book_game_selected(game_id: StringName, entry: BookGameEntry) -> void:
	print("Selected game: ", game_id)

	# Later this will call your GameFlow / MinigameLoader.
	# Example:
	# minigame_loader.load_game(game_id)
