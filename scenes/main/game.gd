extends Node

@onready var book_interactable: BookInteractable = $World/InteractionPoints/BookInteractable
@onready var book_ui: BookUI = $CanvasLayer/BookUI
@onready var table_transition: TableGameTransition = $GameFlow/TableGameTransition

var played_games: Array[StringName] = []
var group_boredom: int = 0
var game_in_progress: bool = false


func _ready() -> void:
	_connect_book_interactable()
	_connect_book_ui()
	_connect_transition()

	if book_ui != null:
		book_ui.visible = false


func _connect_book_interactable() -> void:
	if book_interactable == null:
		return

	var callback := Callable(self, "_on_book_open_requested")

	if book_interactable.has_signal("open_book_requested"):
		if not book_interactable.is_connected("open_book_requested", callback):
			book_interactable.connect("open_book_requested", callback)
		return

	if book_interactable.has_signal("open_requested"):
		if not book_interactable.is_connected("open_requested", callback):
			book_interactable.connect("open_requested", callback)


func _connect_book_ui() -> void:
	if book_ui == null:
		return

	if not book_ui.closed.is_connected(_on_book_ui_closed):
		book_ui.closed.connect(_on_book_ui_closed)

	if not book_ui.game_selected.is_connected(_on_book_game_selected):
		book_ui.game_selected.connect(_on_book_game_selected)


func _connect_transition() -> void:
	if table_transition == null:
		return

	if not table_transition.game_finished.is_connected(_on_card_game_finished):
		table_transition.game_finished.connect(_on_card_game_finished)


func _on_book_open_requested(book: BookInteractable) -> void:
	if game_in_progress:
		return

	open_book_ui()


func open_book_ui() -> void:
	if book_interactable != null:
		book_interactable.set_enabled(false)

	if book_ui == null:
		return

	var available_games: Array[StringName] = [
		&"war"
	]

	var preference_notes := {
		&"war": [
			"[b]Fox[/b]: This one is mostly luck. Which means I can blame luck.",
			"[b]Player[/b]: Flip the bigger card. Easy enough."
		]
	}

	book_ui.open_book(
		available_games,
		played_games,
		preference_notes,
		group_boredom,
		played_games.size()
	)


func _on_book_ui_closed() -> void:
	if game_in_progress:
		return

	if book_interactable != null:
		book_interactable.set_enabled(true)


func _on_book_game_selected(game_id: StringName, entry: BookGameEntry) -> void:
	if entry == null:
		return

	get_tree().paused = false

	game_in_progress = true

	if book_ui != null:
		book_ui.visible = false

	if book_interactable != null:
		book_interactable.set_enabled(false)

	if table_transition != null:
		table_transition.start_card_game(entry)
	else:
		push_warning("Game.gd could not find TableGameTransition.")


func _on_card_game_finished(game_id: StringName, result: Dictionary) -> void:
	if not played_games.has(game_id):
		played_games.append(game_id)

	group_boredom += int(result.get("boredom_delta", 1))
	group_boredom = clamp(group_boredom, 0, 10)

	game_in_progress = false

	open_book_ui()
