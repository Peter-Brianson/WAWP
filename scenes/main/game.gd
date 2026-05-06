extends Node

@export_group("Debug")
@export var show_end_test_button: bool = false:
	set(value):
		show_end_test_button = value
		if is_inside_tree():
			_update_debug_end_button()

@export var debug_end_winner_id: StringName = &"fox"

@onready var book_interactable: BookInteractable = $World/InteractionPoints/BookInteractable
@onready var book_ui: BookUI = $CanvasLayer/BookUI
@onready var player_hand_ui: PlayerHandUI = $CanvasLayer/PlayerHandUI
@onready var table_game_transition: TableGameTransition = $GameFlow/TableGameTransition

var table_dialogue_ui: TableDialogueUI = null
var debug_end_button: Button = null

var available_games: Array[StringName] = [&"war", &"go_fish", &"poker"]
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
	],
	&"poker": [
		"[b]Fox[/b]: Finally. A game where lying is part of the rules.",
		"[b]Owl[/b]: Bluffing is simply probability wearing a mask.",
		"[b]Bear[/b]: I do not like games where the cards have secrets."
	]
}


func _ready() -> void:
	_ensure_table_dialogue_ui()
	_ensure_debug_end_button()
	_update_debug_end_button()

	if book_interactable != null:
		book_interactable.open_requested.connect(_on_book_open_requested)

	if book_ui != null:
		book_ui.closed.connect(_on_book_ui_closed)
		book_ui.game_selected.connect(_on_book_game_selected)

	if table_game_transition != null:
		table_game_transition.game_finished.connect(_on_table_game_finished)

	if player_hand_ui != null:
		player_hand_ui.hide_hand()


func _ensure_table_dialogue_ui() -> void:
	var layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer
	if layer == null:
		return

	table_dialogue_ui = layer.get_node_or_null("TableDialogueUI") as TableDialogueUI

	if table_dialogue_ui == null:
		table_dialogue_ui = TableDialogueUI.new()
		table_dialogue_ui.name = "TableDialogueUI"
		layer.add_child(table_dialogue_ui)


func _ensure_debug_end_button() -> void:
	if debug_end_button != null:
		return

	var layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer
	if layer == null:
		return

	debug_end_button = Button.new()
	debug_end_button.name = "DebugEndTestButton"
	debug_end_button.text = "End Test"
	debug_end_button.theme_type_variation = "GameButton"
	debug_end_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_end_button.offset_left = -132.0
	debug_end_button.offset_top = 16.0
	debug_end_button.offset_right = -16.0
	debug_end_button.offset_bottom = 56.0
	debug_end_button.visible = false
	debug_end_button.pressed.connect(_on_debug_end_test_pressed)
	layer.add_child(debug_end_button)


func _update_debug_end_button() -> void:
	if debug_end_button == null:
		return

	debug_end_button.visible = show_end_test_button and game_running


func _on_debug_end_test_pressed() -> void:
	if table_game_transition == null:
		return

	if table_game_transition.has_method("debug_end_active_game"):
		table_game_transition.call("debug_end_active_game", debug_end_winner_id)


func _on_book_open_requested(book: BookInteractable) -> void:
	if game_running:
		return

	_set_book_available(false, true)

	if player_hand_ui != null:
		player_hand_ui.hide_hand()

	if book_ui == null:
		return

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
	_update_debug_end_button()

	_set_book_available(false, false)

	if player_hand_ui != null:
		player_hand_ui.hide_hand()

	table_game_transition.start_card_game(entry)


func _on_table_game_finished(game_id: StringName, result: Dictionary) -> void:
	game_running = false
	_update_debug_end_button()

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

	if table_dialogue_ui != null:
		table_dialogue_ui.hide_dialogue()

	_set_book_available(true, true)

	print("Finished game: ", game_id, " Result: ", result, " Boredom: ", boredom_value)


func _set_book_available(available: bool, should_be_visible: bool = true) -> void:
	if book_interactable == null:
		return

	book_interactable.visible = should_be_visible
	book_interactable.set_enabled(available)
