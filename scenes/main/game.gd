extends Node

@onready var book_interactable: BookInteractable = $World/InteractionPoints/BookInteractable
@onready var book_ui: BookUI = $CanvasLayer/BookUI
@onready var player_hand_ui: PlayerHandUI = $CanvasLayer/PlayerHandUI
@onready var table_game_transition: TableGameTransition = $GameFlow/TableGameTransition

var available_games: Array[StringName] = [&"war", &"go_fish"]
var played_games: Array[StringName] = []
var boredom_value: int = 0
var games_played_count: int = 0
var game_running: bool = false

var preference_notes := {
	&"war": [
		"[b]Bear[/b]: Finally, a simple one.",
		"[b]Fox[/b]: This barely counts as strategy."
	],
	&"go_fish": [
		"[b]Fox[/b]: I like asking suspicious questions.",
		"[b]Raccoon[/b]: Can I ask for cards I already have?"
	]
}


func _ready() -> void:
	if book_interactable != null:
		book_interactable.open_requested.connect(_on_book_open_requested)

	if book_ui != null:
		book_ui.closed.connect(_on_book_ui_closed)
		book_ui.game_selected.connect(_on_book_game_selected)

	if table_game_transition != null:
		table_game_transition.game_finished.connect(_on_table_game_finished)

	if player_hand_ui != null:
		player_hand_ui.hide_hand()


func _on_book_open_requested(book: BookInteractable) -> void:
	if game_running:
		return

	_set_book_available(false, true)

	if player_hand_ui != null:
		player_hand_ui.hide_hand()

	book_ui.open_book(
		available_games,
		played_games,
		preference_notes,
		boredom_value,
		games_played_count
	)


func _on_book_ui_closed() -> void:
	if game_running:
		return

	_set_book_available(true, true)


func _on_book_game_selected(game_id: StringName, entry: BookGameEntry) -> void:
	if entry == null:
		return

	if table_game_transition == null:
		push_warning("Game.gd could not find GameFlow/TableGameTransition.")
		return

	game_running = true

	# Hide the physical book prop while an actual card game is running.
	_set_book_available(false, false)

	if player_hand_ui != null:
		player_hand_ui.hide_hand()

	table_game_transition.start_card_game(entry)


func _on_table_game_finished(game_id: StringName, result: Dictionary) -> void:
	game_running = false

	if not played_games.has(game_id):
		played_games.append(game_id)

	games_played_count = played_games.size()

	boredom_value += int(result.get("boredom_delta", 1))

	if bool(result.get("felt_slow", false)):
		boredom_value += 1

	if bool(result.get("stalemate", false)):
		boredom_value += 1

	boredom_value = clampi(boredom_value, 0, 10)

	if player_hand_ui != null:
		player_hand_ui.hide_hand()

	_set_book_available(true, true)

	print("Finished game: ", game_id, " Result: ", result, " Boredom: ", boredom_value)

func _set_book_available(available: bool, should_be_visible: bool = true) -> void:
	if book_interactable == null:
		return

	book_interactable.visible = should_be_visible
	book_interactable.set_enabled(available)
