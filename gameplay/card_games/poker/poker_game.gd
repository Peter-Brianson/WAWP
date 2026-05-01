extends Node3D
class_name PokerGame

signal game_finished(result: Dictionary)

enum Phase { NOT_STARTED, PREFLOP, FLOP, TURN, RIVER, SHOWDOWN, FINISHED }

const RANK_LABELS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_VALUES: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]

@export_group("Starting Chips")
@export var starting_chips: int = 50
@export var small_blind: int = 1
@export var big_blind: int = 2

@export_group("Betting")
@export var small_raise_size: int = 2
@export var big_raise_size: int = 5
@export var max_bet_per_round: int = 16

@export_group("Table Positions")
@export var center_deck_position: Vector3 = Vector3(0.0, 0.36, 0.0)
@export var player_seat_position: Vector3 = Vector3(0.0, 0.36, 0.66)
@export var fox_seat_position: Vector3 = Vector3(0.0, 0.36, -0.66)
@export var community_start_position: Vector3 = Vector3(-0.36, 0.42, 0.0)
@export var community_card_spacing: float = 0.18
@export var deck_stack_offset: Vector3 = Vector3(0.48, 0.0, 0.0)
@export var pot_stack_offset: Vector3 = Vector3(0.0, 0.0, -0.22)
@export var player_chips_offset: Vector3 = Vector3(0.28, 0.0, -0.02)
@export var fox_chips_offset: Vector3 = Vector3(0.28, 0.0, 0.02)

@export_group("Pacing")
@export_range(0.05, 2.0, 0.05) var fox_think_pause: float = 0.45
@export_range(0.05, 2.0, 0.05) var deal_pause: float = 0.35
@export_range(0.1, 3.0, 0.1) var showdown_pause: float = 1.2

var table_cards: TableCardRenderer = null
var table_layout_area: TableLayoutArea = null
var player_hand_ui: PlayerHandUI = null
var deck: Array[Dictionary] = []
var player_hole_cards: Array[Dictionary] = []
var fox_hole_cards: Array[Dictionary] = []
var community_cards: Array[Dictionary] = []
var phase: Phase = Phase.NOT_STARTED
var busy: bool = false
var player_chips: int = 0
var fox_chips: int = 0
var pot: int = 0
var current_bet: int = 0
var player_round_bet: int = 0
var fox_round_bet: int = 0
var player_has_acted: bool = false
var fox_has_acted: bool = false
var status_label: Label = null
var detail_label: Label = null
var chip_label: Label = null
var check_call_button: Button = null
var small_raise_button: Button = null
var big_raise_button: Button = null
var fold_button: Button = null
var end_button: Button = null

func _ready() -> void:
	_build_ui()
	_set_action_buttons_enabled(false)

func configure_card_game(context: Dictionary) -> void:
	if context.has("table_card_renderer"):
		table_cards = context["table_card_renderer"] as TableCardRenderer
	if context.has("table_layout_area"):
		table_layout_area = context["table_layout_area"] as TableLayoutArea
	if context.has("player_hand_ui"):
		player_hand_ui = context["player_hand_ui"] as PlayerHandUI
	if table_cards == null:
		table_cards = TableCardRenderer.new()
		table_cards.name = "FallbackTableCardRenderer"
		add_child(table_cards)
	if context.has("center_deck_global"):
		center_deck_position = table_cards.to_local(context["center_deck_global"])
	if context.has("player_seat_global"):
		player_seat_position = table_cards.to_local(context["player_seat_global"]) + Vector3(0.0, 0.05, 0.0)
	if context.has("fox_seat_global"):
		fox_seat_position = table_cards.to_local(context["fox_seat_global"]) + Vector3(0.0, 0.05, 0.0)
	community_start_position = center_deck_position + Vector3(-0.36, 0.06, 0.0)
	if table_layout_area != null:
		center_deck_position = table_cards.to_local(table_layout_area.get_center_global())
		player_seat_position = table_cards.to_local(table_layout_area.get_player_stack_global(0, 2))
		fox_seat_position = table_cards.to_local(table_layout_area.get_player_stack_global(1, 2))
		community_start_position = table_cards.to_local(table_layout_area.get_community_card_global(0, 5))

func start_game() -> void:
	busy = true
	phase = Phase.PREFLOP
	_set_action_buttons_enabled(false)
	if player_hand_ui == null:
		player_hand_ui = get_tree().get_first_node_in_group("player_hand_ui") as PlayerHandUI
	status_label.text = "Poker is starting..."
	detail_label.text = "Texas Hold'em prototype. Bet, call, raise, or fold."
	_start_new_hand()
	await get_tree().create_timer(deal_pause).timeout
	busy = false
	status_label.text = "Preflop betting. You are the small blind."
	detail_label.text = "Call the big blind, raise, or fold."
	_update_ui()

func _build_ui() -> void:
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.name = "PokerCanvasLayer"
	add_child(canvas_layer)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "PokerPanel"
	panel.theme_type_variation = "GamePanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 20.0
	panel.offset_top = 20.0
	panel.offset_right = 500.0
	panel.offset_bottom = 245.0
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
	title.theme_type_variation = "GameTitleLabel"
	box.add_child(title)
	status_label = Label.new()
	status_label.text = "Preparing..."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.theme_type_variation = "GameStatusLabel"
	box.add_child(status_label)
	detail_label = Label.new()
	detail_label.text = ""
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.theme_type_variation = "GameStatusLabel"
	box.add_child(detail_label)
	chip_label = Label.new()
	chip_label.text = ""
	chip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chip_label.theme_type_variation = "GameStatusLabel"
	box.add_child(chip_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	check_call_button = _make_button("Check", _on_check_call_pressed)
	row.add_child(check_call_button)
	small_raise_button = _make_button("Bet 2", _on_small_raise_pressed)
	row.add_child(small_raise_button)
	big_raise_button = _make_button("Bet 5", _on_big_raise_pressed)
	row.add_child(big_raise_button)
	fold_button = _make_button("Fold", _on_fold_pressed)
	row.add_child(fold_button)
	end_button = _make_button("End Test", _on_end_test_pressed)
	row.add_child(end_button)

func _make_button(text: String, callable: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = "GameButton"
	button.pressed.connect(callable)
	return button

func _start_new_hand() -> void:
	deck = _build_standard_deck()
	player_hole_cards.clear()
	fox_hole_cards.clear()
	community_cards.clear()
	player_chips = starting_chips
	fox_chips = starting_chips
	pot = 0
	player_hole_cards.append(_draw_card())
	fox_hole_cards.append(_draw_card())
	player_hole_cards.append(_draw_card())
	fox_hole_cards.append(_draw_card())
	_reset_betting_round()
	_post_blinds()
	_redraw_table(false)
	_update_player_hand_ui()

func _post_blinds() -> void:
	_commit_player_chips(small_blind)
	_commit_fox_chips(big_blind)
	current_bet = big_blind
	player_has_acted = false
	fox_has_acted = false

func _reset_betting_round() -> void:
	current_bet = 0
	player_round_bet = 0
	fox_round_bet = 0
	player_has_acted = false
	fox_has_acted = false

func _build_standard_deck() -> Array[Dictionary]:
	var built_deck: Array[Dictionary] = []
	for suit_index: int in range(SUITS.size()):
		var suit: String = SUITS[suit_index]
		for rank_index: int in range(RANK_LABELS.size()):
			built_deck.append({"rank": RANK_LABELS[rank_index], "value": RANK_VALUES[rank_index], "suit": suit, "text": "%s%s" % [RANK_LABELS[rank_index], suit]})
	built_deck.shuffle()
	return built_deck

func _draw_card() -> Dictionary:
	if deck.is_empty():
		return {}
	return deck.pop_back()

func _update_player_hand_ui() -> void:
	if player_hand_ui == null:
		return
	player_hand_ui.display_hand(player_hole_cards, "Your poker hand. Betting happens in the Poker panel.", false)

func _redraw_table(reveal_fox: bool) -> void:
	if table_cards == null:
		return
	table_cards.clear_all_cards()
	var deck_position: Vector3 = center_deck_position + deck_stack_offset
	var pot_position: Vector3 = center_deck_position + pot_stack_offset
	var player_chip_position: Vector3 = player_seat_position + player_chips_offset
	var fox_chip_position: Vector3 = fox_seat_position + fox_chips_offset
	if table_layout_area != null:
		deck_position = table_cards.to_local(table_layout_area.get_deck_global())
		pot_position = table_cards.to_local(table_layout_area.get_pot_global())
		player_chip_position = table_cards.to_local(table_layout_area.get_offset_global(table_layout_area.get_player_stack_global(0, 2), Vector3(0.20, 0.0, -0.02), 0.04))
		fox_chip_position = table_cards.to_local(table_layout_area.get_offset_global(table_layout_area.get_player_stack_global(1, 2), Vector3(0.20, 0.0, 0.02), 0.04))
	table_cards.show_stack(deck.size(), &"deck", deck_position, true, "Deck")
	table_cards.show_stack(maxi(pot, 1), &"pot", pot_position, true, "Pot %d" % pot)
	table_cards.show_stack(maxi(int(ceil(float(player_chips) / 5.0)), 1), &"player_chips", player_chip_position, true, "You %d" % player_chips)
	table_cards.show_stack(maxi(int(ceil(float(fox_chips) / 5.0)), 1), &"fox_chips", fox_chip_position, true, "Fox %d" % fox_chips)
	for i: int in range(community_cards.size()):
		var pos: Vector3 = table_cards.to_local(table_layout_area.get_community_card_global(i, 5)) if table_layout_area != null else community_start_position + Vector3(community_card_spacing * float(i), 0.0, 0.0)
		table_cards.show_card(community_cards[i], &"community", pos, false)
	for i: int in range(fox_hole_cards.size()):
		var fox_pos: Vector3 = fox_seat_position + Vector3(-0.10 + 0.20 * float(i), 0.04, 0.0)
		table_cards.show_card(fox_hole_cards[i], &"fox_hole", fox_pos, not reveal_fox)

func _update_ui() -> void:
	if phase == Phase.FINISHED:
		_set_action_buttons_enabled(false)
		return
	var to_call: int = _amount_player_must_call()
	chip_label.text = "You: %d chips | Fox: %d chips | Pot: %d | Current bet: %d | To call: %d" % [player_chips, fox_chips, pot, current_bet, to_call]
	check_call_button.text = "Call %d" % to_call if to_call > 0 else "Check"
	small_raise_button.text = "Bet %d" % small_raise_size if current_bet <= 0 else "Raise +%d" % small_raise_size
	big_raise_button.text = "Bet %d" % big_raise_size if current_bet <= 0 else "Raise +%d" % big_raise_size
	var can_act: bool = not busy and phase != Phase.SHOWDOWN and phase != Phase.FINISHED
	check_call_button.disabled = not can_act
	small_raise_button.disabled = not (can_act and _can_player_raise_by(small_raise_size))
	big_raise_button.disabled = not (can_act and _can_player_raise_by(big_raise_size))
	fold_button.disabled = not can_act
	end_button.disabled = false

func _set_action_buttons_enabled(value: bool) -> void:
	for button in [check_call_button, small_raise_button, big_raise_button, fold_button]:
		if button != null:
			button.disabled = not value
	if end_button != null:
		end_button.disabled = false

func _on_check_call_pressed() -> void:
	if busy or phase == Phase.FINISHED:
		return
	var to_call: int = _amount_player_must_call()
	if to_call > 0:
		var paid: int = _commit_player_chips(to_call)
		status_label.text = "You call %d." % paid
	else:
		status_label.text = "You check."
	player_has_acted = true
	await _finish_player_betting_action()

func _on_small_raise_pressed() -> void:
	await _player_bet_or_raise(small_raise_size)

func _on_big_raise_pressed() -> void:
	await _player_bet_or_raise(big_raise_size)

func _player_bet_or_raise(raise_size: int) -> void:
	if busy or phase == Phase.FINISHED:
		return
	var target_bet: int = raise_size if current_bet <= 0 else current_bet + raise_size
	target_bet = mini(target_bet, player_round_bet + player_chips)
	var amount_to_commit: int = target_bet - player_round_bet
	if amount_to_commit <= 0:
		return
	_commit_player_chips(amount_to_commit)
	if player_round_bet > current_bet:
		current_bet = player_round_bet
		fox_has_acted = false
	player_has_acted = true
	status_label.text = "You bet." if current_bet <= 0 else "You raise."
	await _finish_player_betting_action()

func _on_fold_pressed() -> void:
	if busy or phase == Phase.FINISHED:
		return
	status_label.text = "You fold. Fox wins the pot."
	detail_label.text = "Fox drags the chips in with a deeply suspicious grin."
	_redraw_table(true)
	await get_tree().create_timer(showdown_pause).timeout
	_finish_game(&"fox", "Player folded.")

func _on_end_test_pressed() -> void:
	_finish_game(&"fox", "Test ended.")

func _amount_player_must_call() -> int:
	return maxi(current_bet - player_round_bet, 0)

func _amount_fox_must_call() -> int:
	return maxi(current_bet - fox_round_bet, 0)

func _can_player_raise_by(raise_size: int) -> bool:
	if player_chips <= _amount_player_must_call() or current_bet >= max_bet_per_round:
		return false
	var target_bet: int = raise_size if current_bet <= 0 else current_bet + raise_size
	return mini(target_bet, max_bet_per_round) > player_round_bet

func _commit_player_chips(amount: int) -> int:
	var paid: int = clampi(amount, 0, player_chips)
	player_chips -= paid
	player_round_bet += paid
	pot += paid
	return paid

func _commit_fox_chips(amount: int) -> int:
	var paid: int = clampi(amount, 0, fox_chips)
	fox_chips -= paid
	fox_round_bet += paid
	pot += paid
	return paid

func _is_betting_closed() -> bool:
	if player_chips <= 0 or fox_chips <= 0:
		return true
	if player_round_bet != fox_round_bet:
		return false
	return player_has_acted and fox_has_acted

func _finish_player_betting_action() -> void:
	busy = true
	_set_action_buttons_enabled(false)
	_redraw_table(false)
	_update_ui()
	await get_tree().create_timer(fox_think_pause).timeout
	if phase == Phase.FINISHED:
		return
	if _is_betting_closed():
		await _advance_after_betting_round()
		return
	await _take_fox_action()
	_redraw_table(false)
	if phase == Phase.FINISHED:
		return
	if _is_betting_closed():
		await _advance_after_betting_round()
	else:
		busy = false
		_update_ui()

func _take_fox_action() -> void:
	if fox_chips <= 0:
		fox_has_acted = true
		return
	var to_call: int = _amount_fox_must_call()
	var strength: float = _estimate_hand_strength(fox_hole_cards, community_cards)
	if to_call > 0:
		if strength < 0.24 and to_call >= 4 and randf() > 0.25:
			status_label.text = "Fox folds. You win the pot."
			detail_label.text = "Fox decides those cards are suddenly none of his business."
			await get_tree().create_timer(showdown_pause).timeout
			_finish_game(&"player", "Fox folded.")
			return
		if strength > 0.70 and fox_chips > to_call + small_raise_size and current_bet < max_bet_per_round and randf() < 0.35:
			var target_bet: int = mini(current_bet + small_raise_size, max_bet_per_round)
			var paid: int = _commit_fox_chips(target_bet - fox_round_bet)
			current_bet = fox_round_bet
			fox_has_acted = true
			player_has_acted = false
			status_label.text = "Fox raises by %d." % maxi(paid - to_call, 0)
			return
		var called: int = _commit_fox_chips(to_call)
		fox_has_acted = true
		status_label.text = "Fox calls %d." % called
		return
	if strength > 0.62 and fox_chips > 0 and current_bet < max_bet_per_round and randf() < 0.55:
		var bet_amount: int = mini(small_raise_size, fox_chips)
		_commit_fox_chips(bet_amount)
		current_bet = fox_round_bet
		fox_has_acted = true
		player_has_acted = false
		status_label.text = "Fox bets %d." % bet_amount
		return
	fox_has_acted = true
	status_label.text = "Fox checks."

func _advance_after_betting_round() -> void:
	if player_chips <= 0 or fox_chips <= 0:
		await _deal_remaining_and_showdown()
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
			busy = false
			_update_ui()

func _deal_flop() -> void:
	await get_tree().create_timer(deal_pause).timeout
	for i: int in range(3):
		community_cards.append(_draw_card())
	phase = Phase.FLOP
	_reset_betting_round()
	_redraw_table(false)
	status_label.text = "The flop is dealt."
	detail_label.text = _community_text()
	busy = false
	_update_ui()

func _deal_turn() -> void:
	await get_tree().create_timer(deal_pause).timeout
	community_cards.append(_draw_card())
	phase = Phase.TURN
	_reset_betting_round()
	_redraw_table(false)
	status_label.text = "The turn is dealt."
	detail_label.text = _community_text()
	busy = false
	_update_ui()

func _deal_river() -> void:
	await get_tree().create_timer(deal_pause).timeout
	community_cards.append(_draw_card())
	phase = Phase.RIVER
	_reset_betting_round()
	_redraw_table(false)
	status_label.text = "The river is dealt."
	detail_label.text = _community_text()
	busy = false
	_update_ui()

func _deal_remaining_and_showdown() -> void:
	status_label.text = "Someone is all in. Dealing the rest..."
	while community_cards.size() < 5:
		await get_tree().create_timer(deal_pause).timeout
		community_cards.append(_draw_card())
		_redraw_table(false)
	await _showdown()

func _showdown() -> void:
	busy = true
	phase = Phase.SHOWDOWN
	_set_action_buttons_enabled(false)
	_redraw_table(true)
	var player_cards: Array[Dictionary] = []
	var fox_cards: Array[Dictionary] = []
	player_cards.append_array(player_hole_cards)
	player_cards.append_array(community_cards)
	fox_cards.append_array(fox_hole_cards)
	fox_cards.append_array(community_cards)
	var player_eval: Dictionary = _evaluate_best_hand(player_cards)
	var fox_eval: Dictionary = _evaluate_best_hand(fox_cards)
	var comparison: int = _compare_scores(player_eval.get("score", []), fox_eval.get("score", []))
	var winner_id: StringName = &"draw"
	if comparison > 0:
		winner_id = &"player"
		status_label.text = "You win the pot!"
	elif comparison < 0:
		winner_id = &"fox"
		status_label.text = "Fox wins the pot."
	else:
		status_label.text = "The hand is a draw."
	detail_label.text = "You: %s\nFox: %s\nPot: %d" % [String(player_eval.get("label", "Unknown")), String(fox_eval.get("label", "Unknown")), pot]
	await get_tree().create_timer(showdown_pause).timeout
	_finish_game(winner_id, "You: %s | Fox: %s | Pot: %d" % [String(player_eval.get("label", "Unknown")), String(fox_eval.get("label", "Unknown")), pot], String(player_eval.get("label", "")), String(fox_eval.get("label", "")))

func _finish_game(winner_id: StringName, summary: String, player_hand_label: String = "", fox_hand_label: String = "") -> void:
	phase = Phase.FINISHED
	busy = true
	_set_action_buttons_enabled(false)
	if player_hand_ui != null:
		player_hand_ui.hide_hand()
	var result: Dictionary = {"game_id": &"poker", "winner_id": winner_id, "summary": summary, "pot": pot, "player_chips": player_chips, "fox_chips": fox_chips, "player_hand_label": player_hand_label, "fox_hand_label": fox_hand_label, "community_cards": community_cards.duplicate(true), "felt_slow": false, "stalemate": winner_id == &"draw", "boredom_delta": 1}
	game_finished.emit(result)

func _community_text() -> String:
	var parts: Array[String] = []
	for card: Dictionary in community_cards:
		parts.append(String(card.get("text", "?")))
	return "Community: %s" % ", ".join(parts)

func _estimate_hand_strength(hole_cards: Array[Dictionary], board_cards: Array[Dictionary]) -> float:
	var all_cards: Array[Dictionary] = []
	all_cards.append_array(hole_cards)
	all_cards.append_array(board_cards)
	if all_cards.size() >= 5:
		var eval: Dictionary = _evaluate_best_hand(all_cards)
		var score: Array = eval.get("score", [])
		if score.is_empty():
			return 0.2
		return clampf(0.18 + float(int(score[0])) * 0.10, 0.18, 0.95)
	if hole_cards.size() < 2:
		return 0.2
	var a: int = int(hole_cards[0].get("value", 0))
	var b: int = int(hole_cards[1].get("value", 0))
	var strength: float = 0.18 + float(maxi(a, b) - 2) / 20.0 + float(mini(a, b) - 2) / 35.0
	if String(hole_cards[0].get("suit", "")) == String(hole_cards[1].get("suit", "")):
		strength += 0.08
	if a == b:
		strength += 0.28
	if absi(a - b) <= 2:
		strength += 0.05
	return clampf(strength, 0.05, 0.95)

func _evaluate_best_hand(cards: Array[Dictionary]) -> Dictionary:
	var best_eval: Dictionary = {}
	var best_score: Array = []
	if cards.size() < 5:
		return {"label": "High Card", "score": [0, 0]}
	for a: int in range(cards.size() - 4):
		for b: int in range(a + 1, cards.size() - 3):
			for c: int in range(b + 1, cards.size() - 2):
				for d: int in range(c + 1, cards.size() - 1):
					for e: int in range(d + 1, cards.size()):
						var evaluation: Dictionary = _evaluate_five_cards([cards[a], cards[b], cards[c], cards[d], cards[e]])
						var score: Array = evaluation.get("score", [])
						if best_eval.is_empty() or _compare_scores(score, best_score) > 0:
							best_eval = evaluation
							best_score = score
	return best_eval

func _evaluate_five_cards(cards: Array) -> Dictionary:
	var values: Array[int] = []
	var suits: Array[String] = []
	var counts: Dictionary = {}
	for raw_card in cards:
		var card: Dictionary = raw_card
		var value: int = int(card.get("value", 0))
		var suit: String = String(card.get("suit", ""))
		values.append(value)
		suits.append(suit)
		counts[value] = int(counts.get(value, 0)) + 1
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
	fours.sort(); fours.reverse()
	threes.sort(); threes.reverse()
	pairs.sort(); pairs.reverse()
	singles.sort(); singles.reverse()
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
		return _score_result("Two Pair", [2, pairs[0], pairs[1], singles[0]])
	if pairs.size() == 1:
		var pair_score: Array[int] = [1, pairs[0]]
		pair_score.append_array(singles)
		return _score_result("One Pair", pair_score)
	var high_card_score: Array[int] = [0]
	high_card_score.append_array(values)
	return _score_result("High Card", high_card_score)

func _score_result(label: String, score: Array[int]) -> Dictionary:
	return {"label": label, "score": score}

func _is_flush(suits: Array[String]) -> bool:
	if suits.is_empty():
		return false
	var first_suit: String = suits[0]
	for suit: String in suits:
		if suit != first_suit:
			return false
	return true

func _get_straight_high(values: Array[int]) -> int:
	var unique: Array[int] = []
	for value: int in values:
		if not unique.has(value):
			unique.append(value)
	unique.sort()
	unique.reverse()
	if unique.has(14):
		unique.append(1)
	if unique.size() < 5:
		return 0
	for i: int in range(unique.size() - 4):
		var high: int = unique[i]
		if unique[i + 1] == high - 1 and unique[i + 2] == high - 2 and unique[i + 3] == high - 3 and unique[i + 4] == high - 4:
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
