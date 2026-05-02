extends Control
class_name TableScreenLabelOverlay

@export var label_theme_variation: StringName = &"GameStatusLabel"
@export var screen_offset: Vector2 = Vector2(0.0, -36.0)
@export var clamp_to_screen: bool = true
@export var screen_padding: Vector2 = Vector2(12.0, 12.0)
@export var center_labels: bool = true
@export var hide_when_behind_camera: bool = true

var _labels: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	for label_id: Variant in _labels.keys():
		var entry: Dictionary = _labels[label_id]
		var label: Label = entry.get("label", null) as Label
		var anchor: Node3D = entry.get("anchor", null) as Node3D

		if label == null:
			continue

		if anchor == null or not is_instance_valid(anchor):
			label.visible = false
			continue

		if hide_when_behind_camera and camera.is_position_behind(anchor.global_position):
			label.visible = false
			continue

		label.visible = anchor.visible

		var label_size: Vector2 = label.get_combined_minimum_size()
		if label_size.x <= 1.0 or label_size.y <= 1.0:
			label_size = label.size

		label.custom_minimum_size = label_size
		label.size = label_size

		var screen_position: Vector2 = camera.unproject_position(anchor.global_position) + screen_offset

		if center_labels:
			screen_position -= label_size * 0.5

		if clamp_to_screen:
			screen_position.x = clampf(screen_position.x, screen_padding.x, viewport_size.x - label_size.x - screen_padding.x)
			screen_position.y = clampf(screen_position.y, screen_padding.y, viewport_size.y - label_size.y - screen_padding.y)

		label.position = screen_position


func register_label(label_id: String, group_id: StringName, anchor: Node3D, text: String) -> void:
	if anchor == null:
		return

	var label: Label = null

	if _labels.has(label_id):
		label = _labels[label_id].get("label", null) as Label

	if label == null:
		label = Label.new()
		label.name = "TableLabel_%s" % label_id
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

	label.theme_type_variation = String(label_theme_variation)
	label.text = text
	label.visible = true
	label.set_meta("table_card_group", group_id)

	_labels[label_id] = {
		"label": label,
		"anchor": anchor,
		"group_id": group_id
	}


func clear_group(group_id: StringName) -> void:
	var remove_ids: Array = []

	for label_id: Variant in _labels.keys():
		var entry: Dictionary = _labels[label_id]
		if entry.get("group_id", &"") == group_id:
			var label: Label = entry.get("label", null) as Label
			if label != null:
				label.queue_free()
			remove_ids.append(label_id)

	for label_id: Variant in remove_ids:
		_labels.erase(label_id)


func clear_all() -> void:
	for label_id: Variant in _labels.keys():
		var entry: Dictionary = _labels[label_id]
		var label: Label = entry.get("label", null) as Label
		if label != null:
			label.queue_free()

	_labels.clear()
