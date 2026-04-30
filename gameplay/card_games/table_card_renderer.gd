extends Node3D
class_name TableCardRenderer

@export_group("Card Size")
@export var card_size: Vector3 = Vector3(0.24, 0.018, 0.34)
@export_range(0.001, 0.05, 0.001) var label_pixel_size: float = 0.006
@export var label_font_size: int = 48

@export_group("Stack Display")
@export_range(1, 24, 1) var visible_stack_cards: int = 8
@export_range(0.001, 0.04, 0.001) var stack_y_offset: float = 0.008
@export_range(0.0, 0.08, 0.001) var stack_spread: float = 0.012


func clear_all_cards() -> void:
	for child in get_children():
		child.queue_free()


func clear_group(group_id: StringName) -> void:
	for child in get_children():
		if child.has_meta("table_card_group") and child.get_meta("table_card_group") == group_id:
			child.queue_free()


func show_card(
	card: Dictionary,
	group_id: StringName,
	position: Vector3,
	face_down: bool = false,
	rotation_y_degrees: float = 0.0
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TableCard_%s" % String(group_id)
	root.position = position
	root.rotation_degrees.y = rotation_y_degrees
	root.set_meta("table_card_group", group_id)
	add_child(root)

	var body: CSGBox3D = CSGBox3D.new()
	body.name = "CardBody"
	body.size = card_size
	body.material = _make_card_material(face_down)
	root.add_child(body)

	var label: Label3D = Label3D.new()
	label.name = "CardLabel"
	label.text = "★" if face_down else _get_card_text(card)
	label.billboard = 1
	label.font_size = label_font_size
	label.pixel_size = label_pixel_size
	label.position = Vector3(0.0, card_size.y * 2.0, 0.0)
	root.add_child(label)

	return root


func show_stack(
	count: int,
	group_id: StringName,
	position: Vector3,
	face_down: bool = true,
	label_text: String = ""
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TableStack_%s" % String(group_id)
	root.position = position
	root.set_meta("table_card_group", group_id)
	add_child(root)

	var shown_count: int = clampi(count, 0, visible_stack_cards)

	for i: int in range(shown_count):
		var card_root: Node3D = Node3D.new()
		card_root.name = "StackCard_%02d" % i
		card_root.position = Vector3(
			float(i) * stack_spread,
			float(i) * stack_y_offset,
			float(i) * stack_spread
		)
		root.add_child(card_root)

		var body: CSGBox3D = CSGBox3D.new()
		body.name = "CardBody"
		body.size = card_size
		body.material = _make_card_material(face_down)
		card_root.add_child(body)

	if label_text != "":
		var label: Label3D = Label3D.new()
		label.name = "StackLabel"
		label.text = label_text
		label.billboard = 1
		label.font_size = 36
		label.pixel_size = label_pixel_size
		label.position = Vector3(0.0, card_size.y * 4.0 + 0.06, 0.0)
		root.add_child(label)

	return root


func _make_card_material(face_down: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()

	if face_down:
		material.albedo_color = Color(0.22, 0.28, 0.42, 1.0)
	else:
		material.albedo_color = Color(0.88, 0.84, 0.68, 1.0)

	return material


func _get_card_text(card: Dictionary) -> String:
	if card.has("text"):
		return String(card["text"])

	var rank: String = String(card.get("rank", "?"))
	var suit: String = String(card.get("suit", ""))

	return "%s%s" % [rank, suit]
