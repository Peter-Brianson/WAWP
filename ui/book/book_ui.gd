extends Control
class_name BookUI

signal closed
signal game_selected(game_id: StringName, entry: BookGameEntry)

@export_group("Book Pages")
@export var game_entries: Array[BookGameEntry] = []

@export_group("Input")
@export var close_action: StringName = &"ui_cancel"
@export var accept_action: StringName = &"ui_accept"
@export var next_page_action: StringName = &"ui_right"
@export var previous_page_action: StringName = &"ui_left"

@export_group("Behavior")
@export var pause_game_while_open: bool = true
@export var wrap_pages: bool = true
@export var close_after_game_selected: bool = true

@onready var dimmer: ColorRect = $Dimmer
@onready var book_root: Control = $BookRoot

@onready var game_title_label: Label = $BookRoot/LeftPage/GameTitleLabel
@onready var game_description_label: RichTextLabel = $BookRoot/LeftPage/GameDescriptionLabel
@onready var rules_label: RichTextLabel = $BookRoot/LeftPage/RulesLabel
@onready var player_count_label: Label = $BookRoot/LeftPage/PlayerCountLabel

@onready var status_label: Label = $BookRoot/RightPage/StatusLabel
@onready var preference_label: RichTextLabel = $BookRoot/RightPage/PreferenceLabel
@onready var played_stamp_label: Label = $BookRoot/RightPage/PlayedStampLabel

@onready var previous_button: Button = $BookRoot/PreviousButton
@onready var next_button: Button = $BookRoot/NextButton
@onready var play_button: Button = $BookRoot/PlayButton
@onready var close_button: Button = $BookRoot/CloseButton

var current_page_index: int = 0
var available_game_ids: Array[StringName] = []
var played_game_ids: Array[StringName] = []
var preference_notes_by_game: Dictionary = {}
var boredom_value: int = 0
var games_played_count: int = 0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	_connect_buttons()
	_refresh_page()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed(close_action):
		get_viewport().set_input_as_handled()
		close_book()
		return

	if event.is_action_pressed(next_page_action):
		get_viewport().set_input_as_handled()
		next_page()
		return

	if event.is_action_pressed(previous_page_action):
		get_viewport().set_input_as_handled()
		previous_page()
		return

	if event.is_action_pressed(accept_action):
		get_viewport().set_input_as_handled()
		_select_current_game()
		return


func open_book(
	p_available_game_ids: Array[StringName] = [],
	p_played_game_ids: Array[StringName] = [],
	p_preference_notes_by_game: Dictionary = {},
	p_boredom_value: int = 0,
	p_games_played_count: int = 0
) -> void:
	available_game_ids = p_available_game_ids
	played_game_ids = p_played_game_ids
	preference_notes_by_game = p_preference_notes_by_game
	boredom_value = p_boredom_value
	games_played_count = p_games_played_count

	if game_entries.is_empty():
		push_warning("BookUI has no game entries assigned.")
		return

	current_page_index = clamp(current_page_index, 0, game_entries.size() - 1)

	visible = true

	if pause_game_while_open:
		get_tree().paused = true

	_refresh_page()

	if play_button != null:
		play_button.grab_focus()


func close_book() -> void:
	visible = false

	if pause_game_while_open:
		get_tree().paused = false

	closed.emit()


func next_page() -> void:
	if game_entries.is_empty():
		return

	if current_page_index >= game_entries.size() - 1:
		if wrap_pages:
			current_page_index = 0
	else:
		current_page_index += 1

	_refresh_page()


func previous_page() -> void:
	if game_entries.is_empty():
		return

	if current_page_index <= 0:
		if wrap_pages:
			current_page_index = game_entries.size() - 1
	else:
		current_page_index -= 1

	_refresh_page()


func _connect_buttons() -> void:
	if previous_button != null and not previous_button.pressed.is_connected(previous_page):
		previous_button.pressed.connect(previous_page)

	if next_button != null and not next_button.pressed.is_connected(next_page):
		next_button.pressed.connect(next_page)

	if play_button != null and not play_button.pressed.is_connected(_select_current_game):
		play_button.pressed.connect(_select_current_game)

	if close_button != null and not close_button.pressed.is_connected(close_book):
		close_button.pressed.connect(close_book)


func _refresh_page() -> void:
	if not is_inside_tree():
		return

	var entry := _get_current_entry()

	if entry == null:
		_show_empty_page()
		return

	var is_unlocked := _is_entry_unlocked(entry)
	var has_been_played := played_game_ids.has(entry.game_id)

	game_title_label.text = entry.display_name
	game_description_label.text = entry.description
	rules_label.text = "[b]Rules[/b]\n" + entry.rules_summary
	player_count_label.text = "Players: %d-%d" % [entry.min_players, entry.max_players]

	status_label.text = _get_status_text(entry, is_unlocked)
	preference_label.text = _get_preference_text(entry.game_id)
	played_stamp_label.text = "PLAYED" if has_been_played else ""

	if play_button != null:
		play_button.disabled = not is_unlocked
		play_button.text = "Play" if is_unlocked else "Locked"

	if previous_button != null:
		previous_button.disabled = game_entries.size() <= 1

	if next_button != null:
		next_button.disabled = game_entries.size() <= 1


func _show_empty_page() -> void:
	game_title_label.text = "No Games"
	game_description_label.text = "The booklet has no pages yet."
	rules_label.text = ""
	player_count_label.text = ""
	status_label.text = ""
	preference_label.text = ""
	played_stamp_label.text = ""

	if play_button != null:
		play_button.disabled = true
		play_button.text = "Locked"


func _select_current_game() -> void:
	var entry := _get_current_entry()
	if entry == null:
		return

	if not _is_entry_unlocked(entry):
		return

	var selected_game_id := entry.game_id

	if close_after_game_selected:
		close_book()

	game_selected.emit(selected_game_id, entry)


func _get_current_entry() -> BookGameEntry:
	if game_entries.is_empty():
		return null

	current_page_index = clamp(current_page_index, 0, game_entries.size() - 1)
	return game_entries[current_page_index]


func _is_entry_unlocked(entry: BookGameEntry) -> bool:
	if entry == null:
		return false

	if available_game_ids.has(entry.game_id):
		return true

	if entry.starts_unlocked:
		return true

	if boredom_value < entry.min_boredom_required:
		return false

	if games_played_count < entry.min_games_played_required:
		return false

	return true


func _get_status_text(entry: BookGameEntry, is_unlocked: bool) -> String:
	if is_unlocked:
		return "Available"

	var reasons: Array[String] = []

	if boredom_value < entry.min_boredom_required:
		reasons.append("More boredom needed.")

	if games_played_count < entry.min_games_played_required:
		reasons.append("Play more booklet games first.")

	if reasons.is_empty():
		return "Locked"

	return "Locked: " + " ".join(reasons)


func _get_preference_text(game_id: StringName) -> String:
	if preference_notes_by_game.has(game_id):
		var value = preference_notes_by_game[game_id]

		if value is String:
			return value

		if value is Array:
			return "\n".join(value)

	return "[b]Animal Reactions[/b]\nNobody has strong feelings yet."
