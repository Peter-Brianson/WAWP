extends Control
class_name TableDialogueUI

signal line_finished

@export_group("Input")
@export var advance_action: StringName = &"ui_accept"
@export var allow_skip: bool = true

@export_group("Timing")
@export_range(0.1, 10.0, 0.1) var default_duration: float = 1.35
@export_range(0.0, 2.0, 0.05) var after_line_pause: float = 0.10

@export_group("Position")
@export var use_world_anchor: bool = true
@export var fallback_position: Vector2 = Vector2(0.5, 0.72)
@export var screen_offset: Vector2 = Vector2(0.0, -84.0)
@export var clamp_padding: Vector2 = Vector2(24.0, 24.0)

@export_group("Theme Variations")
@export var panel_theme_variation: StringName = &"GamePanel"
@export var speaker_theme_variation: StringName = &"GameTitleLabel"
@export var body_theme_variation: StringName = &"GameStatusLabel"

@onready var bubble_panel: PanelContainer = get_node_or_null("BubblePanel") as PanelContainer
@onready var speaker_label: Label = get_node_or_null("BubblePanel/MarginContainer/VBoxContainer/SpeakerLabel") as Label
@onready var body_label: Label = get_node_or_null("BubblePanel/MarginContainer/VBoxContainer/BodyLabel") as Label

var _current_anchor: Node3D = null
var _waiting: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_ensure_nodes()
	_apply_theme()
	visible = false


func _process(_delta: float) -> void:
	if visible and _current_anchor != null:
		_update_anchor_position()


func _unhandled_input(event: InputEvent) -> void:
	if not allow_skip:
		return

	if not _waiting:
		return

	if event.is_action_pressed(advance_action):
		get_viewport().set_input_as_handled()
		_finish_line()


func say(
	speaker_id: StringName,
	speaker_name: String,
	text: String,
	duration: float = -1.0,
	anchor: Node3D = null
) -> void:
	_show_line(speaker_name, text, anchor)

	var use_duration: float = default_duration if duration <= 0.0 else duration
	await get_tree().create_timer(use_duration).timeout

	if _waiting:
		_finish_line()

	if after_line_pause > 0.0:
		await get_tree().create_timer(after_line_pause).timeout


func say_and_wait(
	speaker_id: StringName,
	speaker_name: String,
	text: String,
	anchor: Node3D = null
) -> void:
	_show_line(speaker_name, text, anchor)
	await line_finished


func hide_dialogue() -> void:
	_waiting = false
	_current_anchor = null
	visible = false


func _show_line(speaker_name: String, text: String, anchor: Node3D) -> void:
	_ensure_nodes()
	_apply_theme()

	_current_anchor = anchor
	_waiting = true
	visible = true

	if speaker_label != null:
		speaker_label.text = speaker_name

	if body_label != null:
		body_label.text = text

	if _current_anchor != null:
		_update_anchor_position()
	else:
		_set_fallback_position()


func _finish_line() -> void:
	if not _waiting:
		return

	_waiting = false
	visible = false
	_current_anchor = null
	line_finished.emit()


func _update_anchor_position() -> void:
	if bubble_panel == null:
		return

	if not use_world_anchor:
		_set_fallback_position()
		return

	var viewport: Viewport = get_viewport()
	var camera: Camera3D = viewport.get_camera_3d()

	if camera == null or _current_anchor == null:
		_set_fallback_position()
		return

	var screen_position: Vector2 = camera.unproject_position(_current_anchor.global_position) + screen_offset
	_set_bubble_screen_position(screen_position)


func _set_fallback_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var screen_position: Vector2 = Vector2(
		viewport_size.x * fallback_position.x,
		viewport_size.y * fallback_position.y
	)
	_set_bubble_screen_position(screen_position)


func _set_bubble_screen_position(screen_position: Vector2) -> void:
	if bubble_panel == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = bubble_panel.size

	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = bubble_panel.custom_minimum_size

	var target_position: Vector2 = screen_position - panel_size * 0.5
	target_position.x = clampf(target_position.x, clamp_padding.x, viewport_size.x - panel_size.x - clamp_padding.x)
	target_position.y = clampf(target_position.y, clamp_padding.y, viewport_size.y - panel_size.y - clamp_padding.y)

	bubble_panel.position = target_position


func _ensure_nodes() -> void:
	if bubble_panel == null:
		bubble_panel = PanelContainer.new()
		bubble_panel.name = "BubblePanel"
		bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble_panel.custom_minimum_size = Vector2(380.0, 112.0)
		add_child(bubble_panel)

		var margin: MarginContainer = MarginContainer.new()
		margin.name = "MarginContainer"
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 12)
		bubble_panel.add_child(margin)

		var box: VBoxContainer = VBoxContainer.new()
		box.name = "VBoxContainer"
		box.add_theme_constant_override("separation", 6)
		margin.add_child(box)

		speaker_label = Label.new()
		speaker_label.name = "SpeakerLabel"
		box.add_child(speaker_label)

		body_label = Label.new()
		body_label.name = "BodyLabel"
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body_label)


func _apply_theme() -> void:
	if bubble_panel != null:
		bubble_panel.theme_type_variation = String(panel_theme_variation)

	if speaker_label != null:
		speaker_label.theme_type_variation = String(speaker_theme_variation)

	if body_label != null:
		body_label.theme_type_variation = String(body_theme_variation)
