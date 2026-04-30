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

@export_group("Deal Animation")
@export_range(0, 52, 1) var visual_deal_cards: int = 16
@export_range(0.01, 1.0, 0.01) var deal_spacing: float = 0.035
@export_range(0.05, 2.0, 0.05) var deal_move_time: float = 0.22

@export_group("Battle Animation")
@export_range(0.05, 2.0, 0.05) var flip_move_time: float = 0.22
@export_range(0.05, 2.0, 0.05) var result_pause_time: float = 0.45

@onready var cards_root: Node3D = get_node_or_null("CardsRoot") as Node3D
@onready var canvas_layer: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer

var player_deck: Array[Dictionary] = []
var fox_deck: Array[Dictionary] = []

var status_label: Label
var count_label: Label
var flip_button: Button
var end_button: Button

var ready_to_play: bool = false
var busy: bool = false
var round_number: int = 0
var face_up_nodes: Array[Node] = []


func _ready() -> void:
	_ensure_nodes()
	_build_ui()
	_set_buttons_enabled(false)


func configure_card_game(context: Dictionary) -> void:
	if context.has("center_deck_global"):
		center_deck_position = to_local(context["center_deck_global"])

	if context.has("player_seat_global"):
		player_deck_position = to_local(context["player_seat_global"]) + Vector3(0.0, 0.04, 0.0)

	if context.has("fox_seat_global"):
		fox_deck_position = to_local(context["fox_seat_global"]) + Vector3(0.0, 0.04, 0.0)

	player_face_up_position = center_deck_position + Vector3(-0.24, 0.04, 0.14)
	fox_face_up_position = center_deck_position + Vector3(0.24, 0.04, -0.14)


func start_game() -> void:
	ready_to_play = false
	busy = true
	_set_buttons_enabled(false)

	status_label.text = "War is starting..."
	count_label.text = ""

	_deal_cards()

	await _animate_initial_deal()

	ready_to_play = true
	busy = false
	_set_buttons_enabled(true)

	status_label.text = "Cards dealt. Press Flip."
	_update_count_label()


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
	panel.name = "WarPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 20.0
	panel.offset_top = 20.0
	panel.offset_right = 430.0
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
	title.text = "War"
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

	flip_button = Button.new()
	flip_button.text = "Flip"
	flip_button.pressed.connect(_on_flip_pressed)
	buttons.add_child(flip_button)

	end_button = Button.new()
	end_button.text = "End Test"
	end_button.pressed.connect(_on_end_pressed)
	buttons.add_child(end_button)


func _deal_cards() -> void:
	player_deck.clear()
	fox_deck.clear()
	round_number = 0

	var deck := _build_standard_deck()

	for i in range(deck.size()):
		var card: Dictionary = deck[i]

		if i % 2 == 0:
			player_deck.append(card)
		else:
			fox_deck.append(card)


func _build_standard_deck() -> Array[Dictionary]:
	var deck: Array[Dictionary] = []

	for suit in SUITS:
		for i in range(RANK_LABELS.size()):
			deck.append({
				"rank": RANK_LABELS[i],
				"value": RANK_VALUES[i],
				"suit": suit,
				"text": "%s%s" % [RANK_LABELS[i], suit]
			})

	deck.shuffle()
	return deck


func _animate_initial_deal() -> void:
	var count := clamp(visual_deal_cards, 0, 52)

	for i in range(count):
		var target := player_deck_position if i % 2 == 0 else fox_deck_position
		target += Vector3(randf_range(-0.035, 0.035), 0.0, randf_range(-0.035, 0.035))

		var card_node := _make_card_visual("?", center_deck_position, true)

		var tween := create_tween()
		tween.tween_property(card_node, "position", target, deal_move_time)
		tween.tween_callback(card_node.queue_free)

		await get_tree().create_timer(deal_spacing).timeout

	await get_tree().create_timer(deal_move_time).timeout


func _on_flip_pressed() -> void:
	if not ready_to_play:
		return

	if busy:
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

		await _show_face_up_cards(player_card, fox_card)

		if int(player_card["value"]) > int(fox_card["value"]):
			final_winner = &"player"
		elif int(fox_card["value"]) > int(player_card["value"]):
			final_winner = &"fox"
		else:
			status_label.text = "War! Both flipped %s." % String(player_card["rank"])
			await get_tree().create_timer(result_pause_time).timeout

			_burn_war_cards(player_deck, pot)
			_burn_war_cards(fox_deck, pot)

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

	if _check_for_game_end():
		return

	busy = false
	_set_buttons_enabled(true)


func _burn_war_cards(deck: Array[Dictionary], pot: Array[Dictionary]) -> void:
	var burn_count := min(3, max(deck.size() - 1, 0))

	for i in range(burn_count):
		pot.append(deck.pop_back())


func _collect_pot(deck: Array[Dictionary], pot: Array[Dictionary]) -> void:
	pot.shuffle()

	for card in pot:
		deck.insert(0, card)

	pot.clear()


func _show_face_up_cards(player_card: Dictionary, fox_card: Dictionary) -> void:
	_clear_face_up_cards()

	var player_card_node := _make_card_visual(String(player_card["text"]), player_deck_position, false)
	var fox_card_node := _make_card_visual(String(fox_card["text"]), fox_deck_position, false)

	face_up_nodes.append(player_card_node)
	face_up_nodes.append(fox_card_node)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_card_node, "position", player_face_up_position, flip_move_time)
	tween.tween_property(fox_card_node, "position", fox_face_up_position, flip_move_time)

	await tween.finished


func _make_card_visual(text: String, start_position: Vector3, face_down: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "CardVisual"
	root.position = start_position
	cards_root.add_child(root)

	var body := CSGBox3D.new()
	body.name = "CardBody"
	body.size = Vector3(0.24, 0.018, 0.34)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.28, 0.42, 1.0) if face_down else Color(0.88, 0.84, 0.68, 1.0)
	body.material = material

	root.add_child(body)

	var label := Label3D.new()
	label.name = "CardLabel"
	label.text = "★" if face_down else text
	label.billboard = 1
	label.font_size = 48
	label.pixel_size = 0.006
	label.position = Vector3(0.0, 0.035, 0.0)
	root.add_child(label)

	return root


func _clear_face_up_cards() -> void:
	for node in face_up_nodes:
		if node != null and is_instance_valid(node):
			node.queue_free()

	face_up_nodes.clear()


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

	var result := {
		"game_id": &"war",
		"winner_id": winner_id,
		"rounds": round_number,
		"felt_slow": round_number > 20,
		"stalemate": winner_id == &"draw",
		"boredom_delta": 1
	}

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
	count_label.text = "Your cards: %d    Fox cards: %d" % [player_deck.size(), fox_deck.size()]
