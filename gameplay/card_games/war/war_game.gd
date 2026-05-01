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

@onready var canvas_layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer

var table_cards: TableCardRenderer = null
var table_layout_area: TableLayoutArea = null
var player_deck: Array[Dictionary] = []
var fox_deck: Array[Dictionary] = []
var status_label: Label
var count_label: Label
var flip_button: Button
var end_button: Button
var ready_to_play: bool = false
var busy: bool = false
var round_number: int = 0

func _ready() -> void:
	_ensure_nodes()
	_build_ui()
	_set_buttons_enabled(false)

func configure_card_game(context: Dictionary) -> void:
	if context.has("table_card_renderer"):
		table_cards = context["table_card_renderer"] as TableCardRenderer
	if context.has("table_layout_area"):
		table_layout_area = context["table_layout_area"] as TableLayoutArea
	if table_cards == null:
		table_cards = TableCardRenderer.new()
		table_cards.name = "FallbackTableCardRenderer"
		add_child(table_cards)
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
	_set_buttons_enabled(false)
	status_label.text = "War is starting..."
	count_label.text = ""
	_deal_cards()
	if table_cards != null:
		table_cards.clear_all_cards()
	await _animate_initial_deal()
	_redraw_table()
	ready_to_play = true
	busy = false
	_set_buttons_enabled(true)
	status_label.text = "Cards dealt.\nPress Flip."
	_update_count_label()

func _ensure_nodes() -> void:
	if canvas_layer == null:
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		add_child(canvas_layer)

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "WarPanel"
	panel.theme_type_variation = "GamePanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 20.0
	panel.offset_top = 20.0
	panel.offset_right = 430.0
	panel.offset_bottom = 185.0
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
	title.text = "War"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "GameTitleLabel"
	box.add_child(title)
	status_label = Label.new()
	status_label.text = "Preparing..."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.theme_type_variation = "GameStatusLabel"
	box.add_child(status_label)
	count_label = Label.new()
	count_label.text = ""
	count_label.theme_type_variation = "GameStatusLabel"
	box.add_child(count_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	flip_button = Button.new()
	flip_button.text = "Flip"
	flip_button.theme_type_variation = "GameButton"
	flip_button.pressed.connect(_on_flip_pressed)
	buttons.add_child(flip_button)
	end_button = Button.new()
	end_button.text = "End Test"
	end_button.theme_type_variation = "GameButton"
	end_button.pressed.connect(_on_end_pressed)
	buttons.add_child(end_button)

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
			deck.append({"rank": RANK_LABELS[rank_index], "value": RANK_VALUES[rank_index], "suit": suit, "text": "%s%s" % [RANK_LABELS[rank_index], suit]})
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

func _on_flip_pressed() -> void:
	if not ready_to_play or busy:
		return
	_play_battle()

func _play_battle() -> void:
	busy = true
	_set_buttons_enabled(false)
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
			status_label.text = "War! Both flipped %s." % String(player_card["rank"])
			await get_tree().create_timer(result_pause_time).timeout
			_burn_war_cards(player_deck, pot)
			_burn_war_cards(fox_deck, pot)
			_show_war_pot_stack(pot.size())
			if player_deck.is_empty() or fox_deck.is_empty():
				break
	if final_winner == &"player":
		_collect_pot(player_deck, pot)
		status_label.text = "Round %d: You win the pile." % round_number
	elif final_winner == &"fox":
		_collect_pot(fox_deck, pot)
		status_label.text = "Round %d: Fox wins the pile." % round_number
	else:
		status_label.text = "War fizzled out."
	_update_count_label()
	await get_tree().create_timer(result_pause_time).timeout
	_redraw_table()
	if _check_for_game_end():
		return
	busy = false
	_set_buttons_enabled(true)

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
	_set_buttons_enabled(false)
	var result: Dictionary = {"game_id": &"war", "winner_id": winner_id, "rounds": round_number, "summary": "Rounds played: %d" % round_number, "felt_slow": round_number > 20, "stalemate": winner_id == &"draw", "boredom_delta": 1}
	if winner_id == &"player":
		status_label.text = "You won War!"
	elif winner_id == &"fox":
		status_label.text = "Fox won War!"
	else:
		status_label.text = "War ended in a draw."
	game_finished.emit(result)

func _on_end_pressed() -> void:
	_finish_game(&"fox")

func _set_buttons_enabled(value: bool) -> void:
	if flip_button != null:
		flip_button.disabled = not value
	if end_button != null:
		end_button.disabled = false

func _update_count_label() -> void:
	count_label.text = "Your cards: %d Fox cards: %d" % [player_deck.size(), fox_deck.size()]
