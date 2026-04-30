extends Node3D
class_name GoFishGame

signal game_finished(result: Dictionary)

const RANK_LABELS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_VALUES: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]

@export_group("Rules")
@export_range(2, 8, 1) var player_count: int = 2
@export var player_id: StringName = &"player"
@export var opponent_id: StringName = &"fox"
@export_range(0.05, 3.0, 0.05) var ai_turn_delay: float = 0.85
@export_range(0.05, 3.0, 0.05) var message_delay: float = 0.7

@export_group("Table Positions")
@export var center_deck_position: Vector3 = Vector3(0.0, 0.36, 0.0)
@export var player_seat_position: Vector3 = Vector3(0.0, 0.36, 0.62)
@export var fox_seat_position: Vector3 = Vector3(0.0, 0.36, -0.62)

@onready var cards_root: Node3D = get_node_or_null("CardsRoot") as Node3D
@onready var canvas_layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer

var player_hand_ui: PlayerHandUI = null
var deck: Array[Dictionary] = []
var player_hand: Array[Dictionary] = []
var fox_hand: Array[Dictionary] = []
var player_books: Array[String] = []
var fox_books: Array[String] = []
var current_turn: StringName = &"player"
var busy: bool = false
var turns_taken: int = 0
var status_label: Label
var count_label: Label
var end_button: Button


func _ready() -> void:
	_ensure_nodes()
	_build_ui()
	_set_status("Preparing Go Fish...")


func configure_card_game(context: Dictionary) -> void:
	if context.has("center_deck_global"):
		center_deck_position = to_local(context["center_deck_global"])
	if context.has("player_seat_global"):
		player_seat_position = to_local(context["player_seat_global"])
	if context.has("fox_seat_global"):
		fox_seat_position = to_local(context["fox_seat_global"])
	if context.has("player_hand_ui"):
		player_hand_ui = context["player_hand_ui"] as PlayerHandUI


func start_game() -> void:
	_find_player_hand_ui_if_missing()
	_connect_player_hand_ui()
	busy = false
	turns_taken = 0
	current_turn = player_id
	player_books.clear()
	fox_books.clear()
	deck = _build_standard_deck()
	player_hand.clear()
	fox_hand.clear()
	_deal_starting_hands()
	_check_books(player_hand, player_books)
	_check_books(fox_hand, fox_books)
	_sort_hand(player_hand)
	_sort_hand(fox_hand)
	_set_status("Go Fish! Choose a card rank to ask Fox for.")
	_refresh_counts()
	_refresh_player_hand(true)


func _ensure_nodes() -> void:
	if cards_root == null:
		cards_root = Node3D.new()
		cards_root.name = "CardsRoot"
		add_child(cards_root)
	if canvas_layer == null:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		add_child(canvas_layer)


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "GoFishPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 20.0
	panel.offset_top = 20.0
	panel.offset_right = 470.0
	panel.offset_bottom = 185.0
	canvas_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Go Fish"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	status_label = Label.new()
	status_label.text = "Preparing..."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	count_label = Label.new()
	count_label.text = ""
	box.add_child(count_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	end_button = Button.new()
	end_button.text = "End Test"
	end_button.pressed.connect(_on_end_pressed)
	buttons.add_child(end_button)


func _find_player_hand_ui_if_missing() -> void:
	if player_hand_ui != null:
		return
	var found := get_tree().get_first_node_in_group("player_hand_ui")
	if found is PlayerHandUI:
		player_hand_ui = found as PlayerHandUI


func _connect_player_hand_ui() -> void:
	if player_hand_ui == null:
		push_warning("GoFishGame could not find PlayerHandUI. Player choices will not be shown.")
		return
	if not player_hand_ui.card_selected.is_connected(_on_player_card_selected):
		player_hand_ui.card_selected.connect(_on_player_card_selected)


func _build_standard_deck() -> Array[Dictionary]:
	var new_deck: Array[Dictionary] = []
	for suit in SUITS:
		for i in range(RANK_LABELS.size()):
			new_deck.append({
				"rank": RANK_LABELS[i],
				"value": RANK_VALUES[i],
				"suit": suit,
				"text": "%s%s" % [RANK_LABELS[i], suit]
			})
	new_deck.shuffle()
	return new_deck


func _deal_starting_hands() -> void:
	var cards_each := 7 if player_count <= 3 else 5
	for i in range(cards_each):
		_draw_to_hand(player_hand)
		_draw_to_hand(fox_hand)


func _draw_to_hand(hand: Array[Dictionary]) -> Dictionary:
	if deck.is_empty():
		return {}
	var card: Dictionary = deck.pop_back()
	hand.append(card)
	return card


func _on_player_card_selected(card: Dictionary, hand_index: int) -> void:
	if busy:
		return
	if current_turn != player_id:
		return
	if card.is_empty():
		return
	var rank := String(card.get("rank", ""))
	if rank == "":
		return
	_play_player_ask(rank)


func _play_player_ask(rank: String) -> void:
	busy = true
	turns_taken += 1
	_refresh_player_hand(false, "Asking Fox for %ss..." % rank)
	await _ask_for_rank(player_id, player_hand, fox_hand, player_books, rank)
	if _check_for_game_end():
		return
	busy = false
	if current_turn == player_id:
		_refresh_player_hand(true, "Choose another rank to ask Fox for.")
	else:
		_refresh_player_hand(false, "Fox is thinking...")
		await get_tree().create_timer(ai_turn_delay).timeout
		_play_fox_turn()


func _play_fox_turn() -> void:
	if busy:
		return
	busy = true
	turns_taken += 1
	current_turn = opponent_id
	_ensure_hand_has_card(fox_hand)
	if fox_hand.is_empty():
		_finish_game()
		return
	var rank := _pick_ai_rank()
	await _ask_for_rank(opponent_id, fox_hand, player_hand, fox_books, rank)
	if _check_for_game_end():
		return
	busy = false
	if current_turn == opponent_id:
		await get_tree().create_timer(ai_turn_delay).timeout
		_play_fox_turn()
	else:
		_refresh_player_hand(true, "Your turn. Choose a rank to ask Fox for.")


func _ask_for_rank(asker_id: StringName, asker_hand: Array[Dictionary], target_hand: Array[Dictionary], asker_books: Array[String], rank: String) -> void:
	var asker_name := "You" if asker_id == player_id else "Fox"
	var target_name := "Fox" if asker_id == player_id else "you"
	_set_status("%s asked %s for %ss." % [asker_name, target_name, rank])
	await get_tree().create_timer(message_delay).timeout

	var matches := _take_cards_of_rank(target_hand, rank)
	if not matches.is_empty():
		for match_card in matches:
			asker_hand.append(match_card)
		_sort_hand(asker_hand)
		_check_books(asker_hand, asker_books)
		_set_status("%s got %d card(s). %s goes again." % [asker_name, matches.size(), asker_name])
		current_turn = asker_id
		_refresh_counts()
		await get_tree().create_timer(message_delay).timeout
		return

	_set_status("Go Fish!")
	await get_tree().create_timer(message_delay).timeout
	var drawn := _draw_to_hand(asker_hand)
	if not drawn.is_empty():
		_sort_hand(asker_hand)
		_check_books(asker_hand, asker_books)
		if String(drawn.get("rank", "")) == rank:
			_set_status("%s drew the right rank and goes again." % asker_name)
			current_turn = asker_id
		else:
			_set_status("%s drew a card. Turn passes." % asker_name)
			current_turn = opponent_id if asker_id == player_id else player_id
	else:
		_set_status("The pond is empty. Turn passes.")
		current_turn = opponent_id if asker_id == player_id else player_id
	_refresh_counts()
	await get_tree().create_timer(message_delay).timeout


func _take_cards_of_rank(hand: Array[Dictionary], rank: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for i in range(hand.size() - 1, -1, -1):
		var card := hand[i]
		if String(card.get("rank", "")) == rank:
			matches.append(card)
			hand.remove_at(i)
	return matches


func _check_books(hand: Array[Dictionary], books: Array[String]) -> void:
	var rank_counts: Dictionary = {}
	for card in hand:
		var rank := String(card.get("rank", ""))
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1
	for rank in rank_counts.keys():
		if int(rank_counts[rank]) >= 4:
			_remove_book_from_hand(hand, String(rank))
			if not books.has(String(rank)):
				books.append(String(rank))


func _remove_book_from_hand(hand: Array[Dictionary], rank: String) -> void:
	var removed := 0
	for i in range(hand.size() - 1, -1, -1):
		if String(hand[i].get("rank", "")) == rank:
			hand.remove_at(i)
			removed += 1
			if removed >= 4:
				return


func _ensure_hand_has_card(hand: Array[Dictionary]) -> void:
	if hand.is_empty() and not deck.is_empty():
		_draw_to_hand(hand)
		_sort_hand(hand)


func _pick_ai_rank() -> String:
	if fox_hand.is_empty():
		return ""
	var card := fox_hand[randi() % fox_hand.size()]
	return String(card.get("rank", ""))


func _sort_hand(hand: Array[Dictionary]) -> void:
	hand.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("value", 0)) < int(b.get("value", 0))
	)


func _refresh_player_hand(allow_input: bool, instruction: String = "") -> void:
	_find_player_hand_ui_if_missing()
	if player_hand_ui == null:
		return
	var text := instruction
	if text == "":
		text = "Choose a card rank to ask Fox for." if allow_input else "Waiting..."
	player_hand_ui.display_hand(player_hand, text, allow_input)


func _refresh_counts() -> void:
	if count_label == null:
		return
	count_label.text = "Deck: %d   Your hand: %d   Fox hand: %d   Books: You %d / Fox %d" % [
		deck.size(),
		player_hand.size(),
		fox_hand.size(),
		player_books.size(),
		fox_books.size()
	]


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _check_for_game_end() -> bool:
	_ensure_hand_has_card(player_hand)
	_ensure_hand_has_card(fox_hand)
	_refresh_counts()
	if deck.is_empty() and player_hand.is_empty() and fox_hand.is_empty():
		_finish_game()
		return true
	if player_books.size() + fox_books.size() >= 13:
		_finish_game()
		return true
	return false


func _finish_game(forced_winner: StringName = &"") -> void:
	busy = true
	if player_hand_ui != null:
		player_hand_ui.set_input_enabled(false)
	var winner_id := forced_winner
	if winner_id == &"":
		if player_books.size() > fox_books.size():
			winner_id = player_id
		elif fox_books.size() > player_books.size():
			winner_id = opponent_id
		else:
			winner_id = &"draw"

	if winner_id == player_id:
		_set_status("You won Go Fish!")
	elif winner_id == opponent_id:
		_set_status("Fox won Go Fish!")
	else:
		_set_status("Go Fish ended in a draw.")

	var result := {
		"game_id": &"go_fish",
		"winner_id": winner_id,
		"turns": turns_taken,
		"player_books": player_books.size(),
		"fox_books": fox_books.size(),
		"felt_slow": turns_taken > 24,
		"stalemate": winner_id == &"draw",
		"boredom_delta": 1
	}
	game_finished.emit(result)


func _on_end_pressed() -> void:
	_finish_game(opponent_id)
