extends Control
class_name WinPopupUI

signal next_requested

@export_group("Input")
@export var next_action: StringName = &"ui_accept"
@export var cancel_action: StringName = &"ui_cancel"

@export_group("Text")
@export var default_title: String = "Game Over"
@export var next_button_text: String = "Next"

@onready var dimmer: ColorRect = get_node_or_null("Dimmer") as ColorRect
@onready var panel: PanelContainer = get_node_or_null("PanelContainer") as PanelContainer
@onready var title_label: Label = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/TitleLabel") as Label
@onready var detail_label: RichTextLabel = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/DetailLabel") as RichTextLabel
@onready var next_button: Button = get_node_or_null("PanelContainer/MarginContainer/VBoxContainer/NextButton") as Button

var _waiting_for_next: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	_ensure_nodes()

	visible = false
	_waiting_for_next = false

	if next_button != null and not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if not _waiting_for_next:
		return

	if event.is_action_pressed(next_action) or event.is_action_pressed(cancel_action):
		get_viewport().set_input_as_handled()
		_confirm_next()


func show_result(game_id: StringName, result: Dictionary) -> void:
	_ensure_nodes()

	visible = true
	_waiting_for_next = true

	var winner_id: StringName = _get_winner_id(result)
	var title_text: String = _get_winner_title(winner_id, result)
	var detail_text: String = _get_detail_text(game_id, result)

	if title_label != null:
		title_label.text = title_text

	if detail_label != null:
		detail_label.text = detail_text

	if next_button != null:
		next_button.text = next_button_text
		next_button.disabled = false
		next_button.grab_focus()


func hide_result() -> void:
	_waiting_for_next = false
	visible = false


func _confirm_next() -> void:
	if not _waiting_for_next:
		return

	_waiting_for_next = false
	visible = false
	next_requested.emit()


func _on_next_pressed() -> void:
	_confirm_next()


func _get_winner_id(result: Dictionary) -> StringName:
	var raw_value: Variant = result.get("winner_id", &"")

	if raw_value is StringName:
		return raw_value

	if raw_value is String:
		return StringName(raw_value)

	return &""


func _get_winner_title(winner_id: StringName, result: Dictionary) -> String:
	if result.has("winner_title"):
		return String(result["winner_title"])

	if result.has("winner_name"):
		return "%s wins!" % String(result["winner_name"])

	match winner_id:
		&"player":
			return "Human wins!"
		&"human":
			return "Human wins!"
		&"human_boy":
			return "Human wins!"
		&"fox":
			return "Fox wins!"
		&"bear":
			return "Bear wins!"
		&"raccoon":
			return "Raccoon wins!"
		&"owl":
			return "Owl wins!"
		&"draw":
			return "Draw!"
		&"tie":
			return "Draw!"
		_:
			return default_title


func _get_detail_text(game_id: StringName, result: Dictionary) -> String:
	var lines: Array[String] = []

	lines.append("[center][b]%s[/b][/center]" % _format_game_name(game_id))

	if result.has("summary"):
		lines.append("")
		lines.append(String(result["summary"]))

	if result.has("pot"):
		lines.append("")
		lines.append("Pot: %d" % int(result["pot"]))

	if result.has("player_hand_label") or result.has("fox_hand_label"):
		lines.append("")

		if result.has("player_hand_label"):
			lines.append("Human: %s" % String(result["player_hand_label"]))

		if result.has("fox_hand_label"):
			lines.append("Fox: %s" % String(result["fox_hand_label"]))

	if lines.size() <= 1:
		lines.append("")
		lines.append("Press %s to continue." % String(next_action))

	return "\n".join(lines)


func _format_game_name(game_id: StringName) -> String:
	var text: String = String(game_id).replace("_", " ")
	var parts: PackedStringArray = text.split(" ", false)
	var formatted_parts: Array[String] = []

	for part_index: int in range(parts.size()):
		var part: String = parts[part_index]

		if part.length() <= 0:
			continue

		var first_letter: String = part.substr(0, 1).to_upper()
		var rest: String = ""

		if part.length() > 1:
			rest = part.substr(1).to_lower()

		formatted_parts.append(first_letter + rest)

	return " ".join(formatted_parts)


func _ensure_nodes() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if dimmer == null:
		dimmer = ColorRect.new()
		dimmer.name = "Dimmer"
		dimmer.color = Color(0.0, 0.0, 0.0, 0.55)
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(dimmer)

	if panel == null:
		panel = PanelContainer.new()
		panel.name = "PanelContainer"
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.custom_minimum_size = Vector2(420.0, 230.0)
		panel.offset_left = -210.0
		panel.offset_top = -115.0
		panel.offset_right = 210.0
		panel.offset_bottom = 115.0
		add_child(panel)

		var margin: MarginContainer = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 18)
		panel.add_child(margin)

		var box: VBoxContainer = VBoxContainer.new()
		box.name = "VBoxContainer"
		box.add_theme_constant_override("separation", 10)
		margin.add_child(box)

		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.text = default_title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 34)
		box.add_child(title_label)

		detail_label = RichTextLabel.new()
		detail_label.name = "DetailLabel"
		detail_label.bbcode_enabled = true
		detail_label.fit_content = true
		detail_label.scroll_active = false
		detail_label.custom_minimum_size = Vector2(360.0, 90.0)
		box.add_child(detail_label)

		next_button = Button.new()
		next_button.name = "NextButton"
		next_button.text = next_button_text
		next_button.custom_minimum_size = Vector2(140.0, 42.0)
		box.add_child(next_button)
