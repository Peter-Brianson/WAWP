extends Node3D
class_name WarGame

signal game_finished(result: Dictionary)

const RANK_LABELS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const RANK_VALUES: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]

@export_group("Table Positions")
@export var center_deck_position: Vector3 = Vector3(0.0, 0.36, 0.0)
@export var player_deck_position: Vector3 = Vector3(0.0, 0.36, 0.62)
@export var fox_deck_position: Vector3 = Vector3(0.0, 0.36, -0.62)
@export var player_face_up_position: Vector3 = Vector3(-0.22, 0.39, 0.18)
@export var fox_face_up_position: Vector3 = Vector3(0.22, 0.39, -0.18)
@export var war_pot_position: Vector3 = Vector3(0.0, 0.40, 0.0)

@export_group("Deal Animation")
@export_range(0, 52, 1) var visual_deal_cards: int = 16
@export_range(0.01, 1.0, 0.01) var deal_spacing: float = 0.035
@export_range(0.05, 2.0, 0.05) var deal_move_time: float = 0.22

@export_group("Battle Animation")
@export_range(0.05, 2.0, 0.05) var flip_move_time: float = 0.22
@export_range(0.05, 2.0, 0.05) var result_pause_time: float = 0.45

var table_cards: TableCardRenderer = null
var table_layout_area: TableLayoutArea = null
var dialogue_ui: TableDialogueUI = null
var dialogue_anchors: Dictionary = {}

var player_deck: Array[Dictionary] = []
var fox_deck: Array[Dictionary] = []

var ready_to_play: bool = false
var busy: bool = false
var round_number: int = 0


func _ready() -> void:
	pass


func configure_card_game(context: Dictionary) -> void:
	if context.has("table_card_renderer"):
		table_cards = context["table_card_renderer"] as TableCardRenderer

	if context.has("table_layout_area"):
		table_layout_area = context["table_layout_area"] as TableLayoutArea

	_configure_dialogue_from_context(context)

	if table_cards == null:
		table_cards = TableCardRenderer.new()
		table_cards.name = "FallbackTableCardRenderer"
		add_child(table_cards)

	if not table_cards.table_piece_clicked.is_connected(_on_table_piece_clicked):
		table_cards.table_piece_clicked.connect(_on_table_piece_clicked)

	if context.has("center_deck_global"):
		center_deck_position = table_cards.to_local(context["center_deck_global"])

	if context.has("player_seat_global"):
		player_deck_position = table_cards.to_local(context["player_seat_global"]) + Vector3(0.0, 0.04, -0.12)

	if context.has("fox_seat_global"):
		fox_deck_position = table_cards.to_local(context["fox_seat_global"]) + Vector3(0.0, 0.04, 0.12)

	player_face_up_position = center_deck_position + Vector3(-0.17, 0.07, 0.10)
	fox_face_up_position = center_deck_position + Vector3(0.17, 0.07, -0.10)
	war_pot_position = center_deck_position + Vector3(0.0, 0.075, 0.0)

	if table_layout_area != null:
		center_deck_position = table_cards.to_local(table_layout_area.get_center_global())
		player_deck_position = table_cards.to_local(table_layout_area.get_player_stack_global(0, 2))
		fox_deck_position = table_cards.to_local(table_layout_area.get_player_stack_global(1, 2))
		player_face_up_position = table_cards.to_local(table_layout_area.get_player_face_up_global(0, 2))
		fox_face_up_position = table_cards.to_local(table_layout_area.get_player_face_up_global(1, 2))
		war_pot_position = table_cards.to_local(table_layout_area.get_pot_global())


func start_game() -> void:
	ready_to_play = false
	busy = true

	_deal_cards()

	if table_cards != null:
		table_cards.clear_all_cards()

	await _animate_initial_deal()

	_redraw_table()

	ready_to_play = true
	busy = false

	await _say(&"fox", "War. Simple rules. Bigger card wins. Click your deck when you're ready.", 2.0)


func debug_end_test(winner_id: StringName = &"fox") -> void:
	_finish_game(winner_id)


func _on_table_piece_clicked(group_id: StringName, piece: Node3D, event: InputEvent) -> void:
	if group_id != &"war_player_deck":
		return

	if not ready_to_play:
		return

	if busy:
		return

	_play_battle()


func _deal_cards() -> void:
	player_deck.clear()
	fox_deck.clear()
	round_number = 0

	var deck: Array[Dictionary] = _build_standard_deck()

	for i: int in range(deck.size()):
		if i % 2 == 0:
			player_deck.append(deck[i])
		else:
			fox_deck.append(deck[i])


func _build_standard_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []

	for suit_index: int in range(SUITS.size()):
		var suit: String = SUITS[suit_index]

		for rank_index: int in range(RANK_LABELS.size()):
			deck.append({
				"rank": RANK_LABELS[rank_index],
				"value": RANK_VALUES[rank_index],
				"suit": suit,
				"text": "%s%s" % [RANK_LABELS[rank_index], suit]
			})

	deck.shuffle()
	return deck


func _animate_initial_deal() -> void:
	if table_cards == null:
		return

	table_cards.clear_group(&"war_deal_animation")

	var count: int = clampi(visual_deal_cards, 0, 52)

	for i: int in range(count):
		var target: Vector3 = player_deck_position if i % 2 == 0 else fox_deck_position
		target += Vector3(randf_range(-0.025, 0.025), 0.0, randf_range(-0.025, 0.025))

		var card_node: Node3D = table_cards.show_card({}, &"war_deal_animation", center_deck_position, true)

		var tween: Tween = create_tween()
		tween.tween_property(card_node, "position", target, deal_move_time)
		tween.tween_callback(card_node.queue_free)

		await get_tree().create_timer(deal_spacing).timeout

	await get_tree().create_timer(deal_move_time).timeout
	table_cards.clear_group(&"war_deal_animation")


func _redraw_table() -> void:
	if table_cards == null:
		return

	table_cards.clear_group(&"war_player_deck")
	table_cards.clear_group(&"war_fox_deck")
	table_cards.clear_group(&"war_face_up")
	table_cards.clear_group(&"war_pot")

	table_cards.show_stack(player_deck.size(), &"war_player_deck", player_deck_position, true, "You %d" % player_deck.size())
	table_cards.show_stack(fox_deck.size(), &"war_fox_deck", fox_deck_position, true, "Fox %d" % fox_deck.size())


func _play_battle() -> void:
	busy = true
	round_number += 1

	var pot: Array[Dictionary] = []
	var final_winner: StringName = &""

	while final_winner == &"":
		if player_deck.is_empty() or fox_deck.is_empty():
			break

		var player_card: Dictionary = player_deck.pop_back()
		var fox_card: Dictionary = fox_deck.pop_back()

		pot.append(player_card)
		pot.append(fox_card)

		await _show_face_up_cards(player_card, fox_card, pot.size())

		var player_value: int = int(player_card["value"])
		var fox_value: int = int(fox_card["value"])

		if player_value > fox_value:
			final_winner = &"player"
		elif fox_value > player_value:
			final_winner = &"fox"
		else:
			await _say(&"fox", "War! Same rank. Now it gets messy.", 1.35)
			await get_tree().create_timer(result_pause_time).timeout

			_burn_war_cards(player_deck, pot)
			_burn_war_cards(fox_deck, pot)
			_show_war_pot_stack(pot.size())

			if player_deck.is_empty() or fox_deck.is_empty():
				break

	if final_winner == &"player":
		_collect_pot(player_deck, pot)
		await _say(&"fox", "Fine. You take that pile.", 1.15)
	elif final_winner == &"fox":
		_collect_pot(fox_deck, pot)
		await _say(&"fox", "Mine.", 0.95)
	else:
		await _say(&"fox", "That fizzled out weird.", 1.1)

	await get_tree().create_timer(result_pause_time).timeout

	_redraw_table()

	if _check_for_game_end():
		return

	busy = false


func _burn_war_cards(deck: Array[Dictionary], pot: Array[Dictionary]) -> void:
	var burn_count: int = mini(3, maxi(deck.size() - 1, 0))

	for i: int in range(burn_count):
		pot.append(deck.pop_back())


func _collect_pot(deck: Array[Dictionary], pot: Array[Dictionary]) -> void:
	pot.shuffle()

	for pot_card: Dictionary in pot:
		deck.insert(0, pot_card)

	pot.clear()


func _show_face_up_cards(player_card: Dictionary, fox_card: Dictionary, pot_count: int) -> void:
	if table_cards == null:
		return

	table_cards.clear_group(&"war_face_up")
	table_cards.clear_group(&"war_pot")

	var player_card_node: Node3D = table_cards.show_card(player_card, &"war_face_up", player_deck_position, false)
	var fox_card_node: Node3D = table_cards.show_card(fox_card, &"war_face_up", fox_deck_position, false)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_card_node, "position", player_face_up_position, flip_move_time)
	tween.tween_property(fox_card_node, "position", fox_face_up_position, flip_move_time)

	_show_war_pot_stack(pot_count)

	await tween.finished


func _show_war_pot_stack(pot_count: int) -> void:
	if table_cards == null:
		return

	table_cards.clear_group(&"war_pot")

	if pot_count <= 2:
		return

	table_cards.show_stack(pot_count, &"war_pot", war_pot_position, true, "Pile %d" % pot_count)


func _check_for_game_end() -> bool:
	if player_deck.is_empty() and fox_deck.is_empty():
		_finish_game(&"draw")
		return true

	if fox_deck.is_empty():
		_finish_game(&"player")
		return true

	if player_deck.is_empty():
		_finish_game(&"fox")
		return true

	return false


func _finish_game(winner_id: StringName) -> void:
	busy = true
	ready_to_play = false

	var result: Dictionary = {
		"game_id": &"war",
		"winner_id": winner_id,
		"rounds": round_number,
		"summary": "Rounds played: %d" % round_number,
		"felt_slow": round_number > 20,
		"stalemate": winner_id == &"draw",
		"boredom_delta": 1
	}

	game_finished.emit(result)


func _configure_dialogue_from_context(context: Dictionary) -> void:
	if context.has("table_dialogue_ui"):
		dialogue_ui = context["table_dialogue_ui"] as TableDialogueUI

	if context.has("dialogue_anchors"):
		dialogue_anchors = context["dialogue_anchors"] as Dictionary


func _get_dialogue_anchor(speaker_id: StringName) -> Node3D:
	var anchor: Variant = dialogue_anchors.get(speaker_id, null)

	if anchor is Node3D:
		return anchor as Node3D

	return null


func _get_speaker_name(speaker_id: StringName) -> String:
	match speaker_id:
		&"player", &"human", &"human_boy":
			return "Human"
		&"fox":
			return "Fox"
		_:
			return String(speaker_id).capitalize()


func _say(speaker_id: StringName, text: String, duration: float = 1.25) -> void:
	if dialogue_ui == null:
		print("%s: %s" % [_get_speaker_name(speaker_id), text])
		return

	await dialogue_ui.say(
		speaker_id,
		_get_speaker_name(speaker_id),
		text,
		duration,
		_get_dialogue_anchor(speaker_id)
	)
