extends Node3D
class_name PokerGame

signal game_finished(result: Dictionary)

enum Phase {
	NOT_STARTED,
	PREFLOP,
	FLOP,
	TURN,
	RIVER,
	SHOWDOWN,
	FINISHED
}

const RANK_LABELS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_VALUES: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]

@export_group("Table Positions")
@export var center_deck_position: Vector3 = Vector3(0.0, 0.36, 0.0)
@export var player_seat_position: Vector3 = Vector3(0.0, 0.36, 0.66)
@export var fox_seat_position: Vector3 = Vector3(0.0, 0.36, -0.66)
@export var community_start_position: Vector3 = Vector3(-0.48, 0.42, 0.0)
@export var community_card_spacing: float = 0.24
@export var deck_stack_offset: Vector3 = Vector3(0.78, 0.0, 0.0)
@export var pot_stack_offset: Vector3 = Vector3(0.0, 0.0, -0.32)

@export_group("Pacing")
@export_range(0.05, 2.0, 0.05) var deal_pause: float = 0.25
@export_range(0.1, 3.0, 0.1) var showdown_pause: float = 1.0

var table_cards: TableCardRenderer = null
@onready var canvas_layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer

var player_hand_ui: PlayerHandUI = null

var deck: Array[Dictionary] = []
var player_hole_cards: Array[Dictionary] = []
var fox_hole_cards: Array[Dictionary] = []
var community_cards: Array[Dictionary] = []

var phase: Phase = Phase.NOT_STARTED
var status_label: Label = null
var detail_label: Label = null
var step_button: Button = null
var fold_button: Button = null
var end_button: Button = null
var busy: bool = false


func _ready() -> void:
	_ensure_nodes()
	_build_ui()
	_set_buttons_enabled(false)


func configure_card_game(context: Dictionary) -> void:
	if context.has("table_card_renderer"):
		table_cards = context["table_card_renderer"] as TableCardRenderer

	if table_cards == null:
		push_warning("PokerGame could not find shared TableCardRenderer. Creating fallback renderer.")
		table_cards = TableCardRenderer.new()
		table_cards.name = "FallbackTableCardRenderer"
		add_child(table_cards)

	if context.has("center_deck_global"):
		center_deck_position = table_cards.to_local(context["center_deck_global"])

	if context.has("player_seat_global"):
		player_seat_position = table_cards.to_local(context["player_seat_global"]) + Vector3(0.0, 0.05, 0.0)

	if context.has("fox_seat_global"):
		fox_seat_position = table_cards.to_local(context["fox_seat_global"]) + Vector3(0.0, 0.05, 0.0)

	community_start_position = center_deck_position + Vector3(-0.48, 0.06, 0.0)


func start_game() -> void:
	busy = true
	phase = Phase.PREFLOP
	_set_buttons_enabled(false)

	status_label.text = "Poker is starting..."
	detail_label.text = "Texas Hold'em prototype: two hole cards, then flop, turn, river."

	player_hand_ui = get_tree().get_first_node_in_group("player_hand_ui") as PlayerHandUI

	_start_new_hand()

	await get_tree().create_timer(deal_pause).timeout

	busy = false
	_set_buttons_enabled(true)
	_update_button_text()
	status_label.text = "Preflop. Your hole cards are in your hand UI."
	detail_label.text = "Press Deal Flop when ready."


func _ensure_nodes() -> void:
	if table_cards == null:
		table_cards = TableCardRenderer.new()
		table_cards.name = "TableCardRenderer"
		add_child(table_cards)

	if canvas_layer == null:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		add_child(canvas_layer)


func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "PokerPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 20.0
	panel.offset_top = 20.0
	panel.offset_right = 460.0
	panel.offset_bottom = 210.0
	canvas_layer.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "Poker"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	status_label = Label.new()
	status_label.text = "Preparing..."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	detail_label = Label.new()
	detail_label.text = ""
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)

	step_button = Button.new()
	step_button.text = "Deal Flop"
	step_button.pressed.connect(_on_step_pressed)
	buttons.add_child(step_button)

	fold_button = Button.new()
	fold_button.text = "Fold"
	fold_button.pressed.connect(_on_fold_pressed)
	buttons.add_child(fold_button)

	end_button = Button.new()
	end_button.text = "End Test"
	end_button.pressed.connect(_on_end_pressed)
	buttons.add_child(end_button)


func _start_new_hand() -> void:
	deck = _build_standard_deck()
	player_hole_cards.clear()
	fox_hole_cards.clear()
	community_cards.clear()

	player_hole_cards.append(_draw_card())
	fox_hole_cards.append(_draw_card())
	player_hole_cards.append(_draw_card())
	fox_hole_cards.append(_draw_card())

	_redraw_table(false)
	_update_player_hand_ui()


func _build_standard_deck() -> Array[Dictionary]:
	var built_deck: Array[Dictionary] = []

	for suit in SUITS:
		for i: int in range(RANK_LABELS.size()):
			var rank: String = RANK_LABELS[i]
			var value: int = RANK_VALUES[i]
			var card: Dictionary = {
				"rank": rank,
				"value": value,
				"suit": suit,
				"text": "%s%s" % [rank, suit]
			}
			built_deck.append(card)

	built_deck.shuffle()
	return built_deck


func _draw_card() -> Dictionary:
	if deck.is_empty():
		return {}

	return deck.pop_back()


func _update_player_hand_ui() -> void:
	if player_hand_ui == null:
		return

	player_hand_ui.display_hand(
		player_hole_cards,
		"Your poker hand. Community cards are on the table.",
		false
	)


func _redraw_table(reveal_fox: bool) -> void:
	if table_cards == null:
		return

	table_cards.clear_all_cards()

	var deck_position: Vector3 = center_deck_position + deck_stack_offset
	var pot_position: Vector3 = center_deck_position + pot_stack_offset

	table_cards.show_stack(deck.size(), &"deck", deck_position, true, "Deck")
	table_cards.show_stack(4, &"pot", pot_position, true, "Pot")

	for i: int in range(community_cards.size()):
		var card: Dictionary = community_cards[i]
		var pos: Vector3 = community_start_position + Vector3(community_card_spacing * float(i), 0.0, 0.0)
		table_cards.show_card(card, &"community", pos, false)

	for i: int in range(fox_hole_cards.size()):
		var fox_pos: Vector3 = fox_seat_position + Vector3(-0.16 + 0.32 * float(i), 0.04, 0.0)
		table_cards.show_card(fox_hole_cards[i], &"fox_hole", fox_pos, not reveal_fox)

	for i: int in range(player_hole_cards.size()):
		var player_pos: Vector3 = player_seat_position + Vector3(-0.16 + 0.32 * float(i), 0.04, 0.0)
		table_cards.show_card(player_hole_cards[i], &"player_hole", player_pos, false)


func _on_step_pressed() -> void:
	if busy:
		return

	match phase:
		Phase.PREFLOP:
			await _deal_flop()

		Phase.FLOP:
			await _deal_turn()

		Phase.TURN:
			await _deal_river()

		Phase.RIVER:
			await _showdown()

		_:
			pass


func _deal_flop() -> void:
	busy = true
	_set_buttons_enabled(false)

	for i: int in range(3):
		community_cards.append(_draw_card())

	phase = Phase.FLOP
	_redraw_table(false)

	status_label.text = "The flop is dealt."
	detail_label.text = _community_text()

	await get_tree().create_timer(deal_pause).timeout

	busy = false
	_set_buttons_enabled(true)
	_update_button_text()


func _deal_turn() -> void:
	busy = true
	_set_buttons_enabled(false)

	community_cards.append(_draw_card())
	phase = Phase.TURN
	_redraw_table(false)

	status_label.text = "The turn is dealt."
	detail_label.text = _community_text()

	await get_tree().create_timer(deal_pause).timeout

	busy = false
	_set_buttons_enabled(true)
	_update_button_text()


func _deal_river() -> void:
	busy = true
	_set_buttons_enabled(false)

	community_cards.append(_draw_card())
	phase = Phase.RIVER
	_redraw_table(false)

	status_label.text = "The river is dealt."
	detail_label.text = _community_text()

	await get_tree().create_timer(deal_pause).timeout

	busy = false
	_set_buttons_enabled(true)
	_update_button_text()


func _showdown() -> void:
	busy = true
	_set_buttons_enabled(false)
	phase = Phase.SHOWDOWN

	_redraw_table(true)

	var player_cards: Array[Dictionary] = []
	var fox_cards: Array[Dictionary] = []

	player_cards.append_array(player_hole_cards)
	player_cards.append_array(community_cards)

	fox_cards.append_array(fox_hole_cards)
	fox_cards.append_array(community_cards)

	var player_eval: Dictionary = _evaluate_best_hand(player_cards)
	var fox_eval: Dictionary = _evaluate_best_hand(fox_cards)
	var comparison: int = _compare_scores(
		player_eval.get("score", []),
		fox_eval.get("score", [])
	)

	var winner_id: StringName = &"draw"

	if comparison > 0:
		winner_id = &"player"
		status_label.text = "You win the hand!"
	elif comparison < 0:
		winner_id = &"fox"
		status_label.text = "Fox wins the hand."
	else:
		status_label.text = "The hand is a draw."

	detail_label.text = "You: %s\nFox: %s" % [
		String(player_eval.get("label", "Unknown")),
		String(fox_eval.get("label", "Unknown"))
	]

	await get_tree().create_timer(showdown_pause).timeout

	_finish_game(winner_id, player_eval, fox_eval)


func _finish_game(winner_id: StringName, player_eval: Dictionary = {}, fox_eval: Dictionary = {}) -> void:
	phase = Phase.FINISHED
	busy = true
	_set_buttons_enabled(false)

	var result: Dictionary = {
		"game_id": &"poker",
		"winner_id": winner_id,
		"community_cards": community_cards.duplicate(true),
		"player_hand_label": String(player_eval.get("label", "")),
		"fox_hand_label": String(fox_eval.get("label", "")),
		"felt_slow": false,
		"stalemate": winner_id == &"draw",
		"boredom_delta": 1
	}

	if player_hand_ui != null:
		player_hand_ui.hide_hand()

	game_finished.emit(result)


func _on_fold_pressed() -> void:
	if busy:
		return

	status_label.text = "You folded. Fox wins the hand."
	detail_label.text = ""
	_redraw_table(true)
	_finish_game(&"fox")


func _on_end_pressed() -> void:
	_finish_game(&"fox")


func _set_buttons_enabled(value: bool) -> void:
	if step_button != null:
		step_button.disabled = not value

	if fold_button != null:
		fold_button.disabled = not value

	if end_button != null:
		end_button.disabled = false


func _update_button_text() -> void:
	match phase:
		Phase.PREFLOP:
			step_button.text = "Deal Flop"
		Phase.FLOP:
			step_button.text = "Deal Turn"
		Phase.TURN:
			step_button.text = "Deal River"
		Phase.RIVER:
			step_button.text = "Showdown"
		_:
			step_button.text = "Done"


func _community_text() -> String:
	var parts: Array[String] = []

	for card in community_cards:
		parts.append(String(card.get("text", "?")))

	return "Community: %s" % ", ".join(parts)


func _evaluate_best_hand(cards: Array[Dictionary]) -> Dictionary:
	var best_eval: Dictionary = {}
	var best_score: Array = []

	for a: int in range(cards.size() - 4):
		for b: int in range(a + 1, cards.size() - 3):
			for c: int in range(b + 1, cards.size() - 2):
				for d: int in range(c + 1, cards.size() - 1):
					for e: int in range(d + 1, cards.size()):
						var five_cards: Array[Dictionary] = [
							cards[a],
							cards[b],
							cards[c],
							cards[d],
							cards[e]
						]

						var evaluation: Dictionary = _evaluate_five_cards(five_cards)
						var score: Array = evaluation.get("score", [])

						if best_eval.is_empty() or _compare_scores(score, best_score) > 0:
							best_eval = evaluation
							best_score = score

	return best_eval


func _evaluate_five_cards(cards: Array[Dictionary]) -> Dictionary:
	var values: Array[int] = []
	var suits: Array[String] = []
	var counts: Dictionary = {}

	for card in cards:
		var value: int = int(card.get("value", 0))
		var suit: String = String(card.get("suit", ""))

		values.append(value)
		suits.append(suit)

		if not counts.has(value):
			counts[value] = 0

		counts[value] = int(counts[value]) + 1

	values.sort()
	values.reverse()

	var is_flush: bool = _is_flush(suits)
	var straight_high: int = _get_straight_high(values)

	var fours: Array[int] = []
	var threes: Array[int] = []
	var pairs: Array[int] = []
	var singles: Array[int] = []

	for key in counts.keys():
		var value_key: int = int(key)
		var amount: int = int(counts[key])

		if amount == 4:
			fours.append(value_key)
		elif amount == 3:
			threes.append(value_key)
		elif amount == 2:
			pairs.append(value_key)
		else:
			singles.append(value_key)

	fours.sort()
	fours.reverse()
	threes.sort()
	threes.reverse()
	pairs.sort()
	pairs.reverse()
	singles.sort()
	singles.reverse()

	if is_flush and straight_high > 0:
		return _score_result("Straight Flush", [8, straight_high])

	if not fours.is_empty():
		return _score_result("Four of a Kind", [7, fours[0], singles[0]])

	if not threes.is_empty() and (not pairs.is_empty() or threes.size() > 1):
		var full_pair: int = pairs[0] if not pairs.is_empty() else threes[1]
		return _score_result("Full House", [6, threes[0], full_pair])

	if is_flush:
		var flush_score: Array[int] = [5]
		flush_score.append_array(values)
		return _score_result("Flush", flush_score)

	if straight_high > 0:
		return _score_result("Straight", [4, straight_high])

	if not threes.is_empty():
		var trips_score: Array[int] = [3, threes[0]]
		trips_score.append_array(singles)
		return _score_result("Three of a Kind", trips_score)

	if pairs.size() >= 2:
		var two_pair_score: Array[int] = [2, pairs[0], pairs[1], singles[0]]
		return _score_result("Two Pair", two_pair_score)

	if pairs.size() == 1:
		var pair_score: Array[int] = [1, pairs[0]]
		pair_score.append_array(singles)
		return _score_result("One Pair", pair_score)

	var high_card_score: Array[int] = [0]
	high_card_score.append_array(values)
	return _score_result("High Card", high_card_score)


func _score_result(label: String, score: Array[int]) -> Dictionary:
	return {
		"label": label,
		"score": score
	}


func _is_flush(suits: Array[String]) -> bool:
	if suits.is_empty():
		return false

	var first_suit: String = suits[0]

	for suit in suits:
		if suit != first_suit:
			return false

	return true


func _get_straight_high(values: Array[int]) -> int:
	var unique: Array[int] = []

	for value in values:
		if not unique.has(value):
			unique.append(value)

	unique.sort()
	unique.reverse()

	if unique.has(14) and not unique.has(1):
		unique.append(1)

	if unique.size() < 5:
		return 0

	for i: int in range(unique.size() - 4):
		var high: int = unique[i]

		if unique[i + 1] == high - 1 \
		and unique[i + 2] == high - 2 \
		and unique[i + 3] == high - 3 \
		and unique[i + 4] == high - 4:
			return high

	return 0


func _compare_scores(left_score: Array, right_score: Array) -> int:
	var max_count: int = mini(left_score.size(), right_score.size())

	for i: int in range(max_count):
		var left_value: int = int(left_score[i])
		var right_value: int = int(right_score[i])

		if left_value > right_value:
			return 1

		if left_value < right_value:
			return -1

	if left_score.size() > right_score.size():
		return 1

	if left_score.size() < right_score.size():
		return -1

	return 0
