extends Control
class_name PlayerHandUI

signal card_selected(card: Dictionary, hand_index: int)
signal close_requested

@export_group("Text")
@export var title_text: String = "Your Hand"
@export var default_instruction: String = "Choose a card."

@export_group("Card Art")
@export var card_atlas: CardTextureAtlas
@export var use_card_atlas_art: bool = true
@export var show_text_when_atlas_missing: bool = true

@export_group("Theme Variations")
@export var panel_theme_variation: StringName = &"GamePanel"
@export var title_theme_variation: StringName = &"GameTitleLabel"
@export var instruction_theme_variation: StringName = &"GameStatusLabel"
@export var button_theme_variation: StringName = &"GameButton"
@export var card_theme_variation: StringName = &"CardButton"
@export var hovered_card_theme_variation: StringName = &"HoveredCardButton"
@export var selected_card_theme_variation: StringName = &"SelectedCardButton"

@export_group("Card Fan")
@export var card_button_size: Vector2 = Vector2(88.0, 126.0)
@export var card_overlap: float = 38.0
@export var max_rotation_degrees: float = 13.0
@export var fan_curve_height: float = 22.0
@export var hover_lift: float = 34.0
@export var selected_lift: float = 42.0
@export var hover_scale: float = 1.14
@export var selected_scale: float = 1.18
@export var fan_side_padding: float = 40.0
@export var fan_area_min_height: float = 210.0
@export var panel_height: float = 260.0

@export_group("Behavior")
@export var show_close_button: bool = false
@export var select_on_click: bool = true
@export var keep_selected_card_raised: bool = true

@onready var panel: PanelContainer = get_node_or_null("PanelContainer") as PanelContainer
@onready var title_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/TitleLabel") as Label
@onready var instruction_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/InstructionLabel") as Label
@onready var scroll_container: ScrollContainer = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/ScrollContainer") as ScrollContainer
@onready var close_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/BottomRow/CloseButton") as Button

var current_hand: Array[Dictionary] = []
var input_enabled: bool = true
var card_fan: Control = null
var _card_buttons: Array[Button] = []
var _hovered_hand_index: int = -1
var _selected_hand_index: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player_hand_ui")
	_ensure_nodes()
	_apply_theme_variations()
	_setup_panel_sizing()
	visible = false
	if close_button != null:
		close_button.visible = show_close_button
		if not close_button.pressed.is_connected(_on_close_pressed):
			close_button.pressed.connect(_on_close_pressed)
	if scroll_container != null and not scroll_container.resized.is_connected(_layout_cards):
		scroll_container.resized.connect(_layout_cards)
	clear_hand()

func display_hand(hand: Array, instruction: String = "", allow_input: bool = true) -> void:
	current_hand.clear()
	for value in hand:
		if value is Dictionary:
			current_hand.append((value as Dictionary).duplicate(true))
	input_enabled = allow_input
	_hovered_hand_index = -1
	_selected_hand_index = -1
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
	for button: Button in _card_buttons:
		if button != null:
			button.disabled = not input_enabled
			button.focus_mode = Control.FOCUS_ALL if input_enabled else Control.FOCUS_NONE
	_layout_cards()

func clear_hand() -> void:
	current_hand.clear()
	_hovered_hand_index = -1
	_selected_hand_index = -1
	_clear_card_buttons()
	if instruction_label != null:
		instruction_label.text = default_instruction

func hide_hand() -> void:
	visible = false
	clear_hand()

func set_selected_index(hand_index: int) -> void:
	_selected_hand_index = hand_index
	_layout_cards()

func clear_selected_card() -> void:
	_selected_hand_index = -1
	_layout_cards()

func _ensure_nodes() -> void:
	if panel == null:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel = PanelContainer.new()
		panel.name = "PanelContainer"
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		add_child(panel)
		var margin: MarginContainer = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)
		var box: VBoxContainer = VBoxContainer.new()
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
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll_container)
		var bottom_row: HBoxContainer = HBoxContainer.new()
		bottom_row.name = "BottomRow"
		bottom_row.alignment = BoxContainer.ALIGNMENT_END
		box.add_child(bottom_row)
		close_button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "Close"
		bottom_row.add_child(close_button)
	if scroll_container == null:
		return
	card_fan = scroll_container.get_node_or_null("CardFan") as Control
	if card_fan == null:
		for child: Node in scroll_container.get_children():
			child.queue_free()
		card_fan = Control.new()
		card_fan.name = "CardFan"
		card_fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_fan.clip_contents = false
		scroll_container.add_child(card_fan)

func _apply_theme_variations() -> void:
	if panel != null:
		panel.theme_type_variation = String(panel_theme_variation)
	if title_label != null:
		title_label.theme_type_variation = String(title_theme_variation)
	if instruction_label != null:
		instruction_label.theme_type_variation = String(instruction_theme_variation)
	if close_button != null:
		close_button.theme_type_variation = String(button_theme_variation)

func _setup_panel_sizing() -> void:
	if panel != null:
		panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		panel.offset_left = 40.0
		panel.offset_top = -panel_height
		panel.offset_right = -40.0
		panel.offset_bottom = -20.0
	if scroll_container != null:
		scroll_container.custom_minimum_size = Vector2(0.0, fan_area_min_height)
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.clip_contents = true
	if card_fan != null:
		card_fan.custom_minimum_size = Vector2(0.0, fan_area_min_height)
		card_fan.clip_contents = false

func _rebuild_card_buttons() -> void:
	_clear_card_buttons()
	if card_fan == null:
		return
	if current_hand.is_empty():
		var empty_label: Label = Label.new()
		empty_label.name = "EmptyHandLabel"
		empty_label.text = "No cards in hand."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(300.0, fan_area_min_height)
		empty_label.theme_type_variation = String(instruction_theme_variation)
		card_fan.add_child(empty_label)
		card_fan.custom_minimum_size = empty_label.custom_minimum_size
		return
	for i: int in range(current_hand.size()):
		var card: Dictionary = current_hand[i]
		var button: Button = Button.new()
		button.name = "Card_%02d" % i
		button.tooltip_text = _get_card_tooltip(card)
		button.custom_minimum_size = card_button_size
		button.size = card_button_size
		button.pivot_offset = card_button_size * 0.5
		button.disabled = not input_enabled
		button.focus_mode = Control.FOCUS_ALL if input_enabled else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.theme_type_variation = String(card_theme_variation)
		_apply_card_button_art(button, card)
		button.mouse_entered.connect(_on_card_hovered.bind(i))
		button.mouse_exited.connect(_on_card_unhovered.bind(i))
		button.focus_entered.connect(_on_card_hovered.bind(i))
		button.focus_exited.connect(_on_card_unhovered.bind(i))
		button.pressed.connect(_on_card_button_pressed.bind(card.duplicate(true), i))
		card_fan.add_child(button)
		_card_buttons.append(button)
	_layout_cards()

func _apply_card_button_art(button: Button, card: Dictionary) -> void:
	if use_card_atlas_art and card_atlas != null:
		var texture: Texture2D = card_atlas.get_card_texture(card)
		if texture != null:
			button.icon = texture
			button.expand_icon = true
			button.text = ""
			button.tooltip_text = _get_card_tooltip(card)
			return
	button.icon = null
	button.text = _get_card_label(card) if show_text_when_atlas_missing else ""

func _clear_card_buttons() -> void:
	_card_buttons.clear()
	if card_fan == null:
		return
	for child: Node in card_fan.get_children():
		child.queue_free()

func _layout_cards() -> void:
	if card_fan == null or _card_buttons.is_empty():
		return
	var count: int = _card_buttons.size()
	var card_width: float = card_button_size.x
	var card_height: float = card_button_size.y
	var step: float = maxf(18.0, card_width - card_overlap)
	var total_width: float = card_width + step * float(maxi(count - 1, 0))
	var visible_width: float = scroll_container.size.x if scroll_container != null else 0.0
	var fan_width: float = maxf(visible_width, total_width + fan_side_padding * 2.0)
	var fan_height: float = maxf(fan_area_min_height, card_height + selected_lift + fan_curve_height + 36.0)
	card_fan.custom_minimum_size = Vector2(fan_width, fan_height)
	card_fan.size = Vector2(fan_width, fan_height)
	var start_x: float = (fan_width - total_width) * 0.5
	var safe_top_padding: float = selected_lift + 12.0
	for i: int in range(count):
		var button: Button = _card_buttons[i]
		if button == null:
			continue
		var t: float = 0.0
		if count > 1:
			t = remap(float(i), 0.0, float(count - 1), -1.0, 1.0)
		var is_hovered: bool = i == _hovered_hand_index
		var is_selected: bool = keep_selected_card_raised and i == _selected_hand_index
		var is_featured: bool = is_hovered or is_selected
		var x: float = start_x + step * float(i)
		var y: float = safe_top_padding + absf(t) * fan_curve_height
		var rotation_amount: float = deg_to_rad(t * max_rotation_degrees)
		var scale_amount: Vector2 = Vector2.ONE
		if is_selected:
			y -= selected_lift
			rotation_amount *= 0.15
			scale_amount = Vector2(selected_scale, selected_scale)
		elif is_hovered:
			y -= hover_lift
			rotation_amount *= 0.25
			scale_amount = Vector2(hover_scale, hover_scale)
		button.position = Vector2(x, y)
		button.size = card_button_size
		button.pivot_offset = card_button_size * 0.5
		button.rotation = rotation_amount
		button.scale = scale_amount
		button.z_index = 100 + i if is_featured else i
		_apply_card_style(button, is_hovered, is_selected)

func _apply_card_style(button: Button, is_hovered: bool, is_selected: bool) -> void:
	if button == null:
		return
	if is_selected:
		button.theme_type_variation = String(selected_card_theme_variation)
	elif is_hovered:
		button.theme_type_variation = String(hovered_card_theme_variation)
	else:
		button.theme_type_variation = String(card_theme_variation)

func _get_card_label(card: Dictionary) -> String:
	if card.has("text"):
		return String(card["text"])
	return "%s\n%s" % [String(card.get("rank", "?")), String(card.get("suit", ""))]

func _get_card_tooltip(card: Dictionary) -> String:
	return "Ask for %ss" % String(card.get("rank", "?"))

func _on_card_hovered(hand_index: int) -> void:
	if not input_enabled:
		return
	_hovered_hand_index = hand_index
	_layout_cards()

func _on_card_unhovered(hand_index: int) -> void:
	if _hovered_hand_index != hand_index:
		return
	_hovered_hand_index = -1
	_layout_cards()

func _on_card_button_pressed(card: Dictionary, hand_index: int) -> void:
	if not input_enabled:
		return
	if select_on_click:
		_selected_hand_index = hand_index
		_layout_cards()
	card_selected.emit(card, hand_index)

func _on_close_pressed() -> void:
	close_requested.emit()
