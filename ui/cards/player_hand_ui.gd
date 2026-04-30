extends Control
class_name PlayerHandUI

signal card_selected(card: Dictionary, hand_index: int)
signal close_requested

@export var title_text: String = "Your Hand"
@export var default_instruction: String = "Choose a card."
@export var card_button_min_size: Vector2 = Vector2(72.0, 104.0)
@export var show_close_button: bool = false

@onready var panel: PanelContainer = get_node_or_null("PanelContainer") as PanelContainer
@onready var title_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/TitleLabel") as Label
@onready var instruction_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/InstructionLabel") as Label
@onready var scroll_container: ScrollContainer = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ScrollContainer") as ScrollContainer
@onready var card_row: HBoxContainer = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/CardRow") as HBoxContainer
@onready var close_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/BottomRow/CloseButton") as Button

var current_hand: Array[Dictionary] = []
var input_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player_hand_ui")
	_ensure_nodes()
	visible = false
	if close_button != null:
		close_button.visible = show_close_button
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)
	clear_hand()


func display_hand(hand: Array, instruction: String = "", allow_input: bool = true) -> void:
	current_hand.clear()
	for value in hand:
		if value is Dictionary:
			current_hand.append((value as Dictionary).duplicate(true))

	input_enabled = allow_input
	visible = true

	if title_label != null:
		title_label.text = title_text
	if instruction_label != null:
		instruction_label.text = instruction if instruction != "" else default_instruction

	_rebuild_card_buttons()


func set_instruction(text: String) -> void:
	if instruction_label != null:
		instruction_label.text = text


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if card_row == null:
		return
	for child in card_row.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = not input_enabled


func clear_hand() -> void:
	current_hand.clear()
	_clear_card_buttons()
	if instruction_label != null:
		instruction_label.text = default_instruction


func hide_hand() -> void:
	visible = false
	clear_hand()


func _ensure_nodes() -> void:
	if panel != null and card_row != null:
		return

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel = PanelContainer.new()
	panel.name = "PanelContainer"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 40.0
	panel.offset_top = -170.0
	panel.offset_right = -40.0
	panel.offset_bottom = -20.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "VBoxContainer"
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title_text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	instruction_label = Label.new()
	instruction_label.name = "InstructionLabel"
	instruction_label.text = default_instruction
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(instruction_label)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.custom_minimum_size = Vector2(0.0, 112.0)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll_container)

	card_row = HBoxContainer.new()
	card_row.name = "CardRow"
	card_row.add_theme_constant_override("separation", 8)
	scroll_container.add_child(card_row)

	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(bottom_row)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	bottom_row.add_child(close_button)


func _rebuild_card_buttons() -> void:
	_clear_card_buttons()

	if card_row == null:
		return

	if current_hand.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in hand."
		card_row.add_child(empty_label)
		return

	for i in range(current_hand.size()):
		var card := current_hand[i]
		var button := Button.new()
		button.custom_minimum_size = card_button_min_size
		button.text = _get_card_label(card)
		button.tooltip_text = _get_card_tooltip(card)
		button.disabled = not input_enabled
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_card_button_pressed.bind(card.duplicate(true), i))
		card_row.add_child(button)


func _clear_card_buttons() -> void:
	if card_row == null:
		return
	for child in card_row.get_children():
		child.queue_free()


func _get_card_label(card: Dictionary) -> String:
	if card.has("text"):
		return String(card["text"])
	return "%s%s" % [String(card.get("rank", "?")), String(card.get("suit", ""))]


func _get_card_tooltip(card: Dictionary) -> String:
	return "Ask for %ss" % String(card.get("rank", "?"))


func _on_card_button_pressed(card: Dictionary, hand_index: int) -> void:
	if not input_enabled:
		return
	card_selected.emit(card, hand_index)


func _on_close_pressed() -> void:
	close_requested.emit()
