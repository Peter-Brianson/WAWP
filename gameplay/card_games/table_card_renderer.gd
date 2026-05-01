extends Node3D
class_name TableCardRenderer

@export_group("Card Size")
@export var card_size: Vector3 = Vector3(0.145, 0.01, 0.205)
@export_range(0.001, 0.05, 0.001) var label_pixel_size: float = 0.0038
@export var label_font_size: int = 40

@export_group("Atlas Art")
@export var card_atlas: CardTextureAtlas
@export var use_atlas_cards: bool = true
@export var card_sprite_pixel_size: float = 0.0022

@export_group("Stack Display")
@export_range(1, 24, 1) var visible_stack_cards: int = 4
@export_range(0.001, 0.04, 0.001) var stack_y_offset: float = 0.003
@export_range(0.0, 0.08, 0.001) var stack_spread: float = 0.004
@export var stack_label_offset: Vector3 = Vector3(0.0, 0.16, 0.0)

@export_group("Table Bounds")
@export var table_layout_area_path: NodePath = ^"../TableLayoutArea"
@export var constrain_to_table_bounds: bool = true
@export_range(0.0, 0.25, 0.005) var card_bounds_margin: float = 0.045

@export_group("3D Text Style")
@export var show_stack_labels: bool = true
@export var table_text_color: Color = Color(1.0, 1.0, 0.88, 1.0)
@export var table_text_outline_color: Color = Color(0.02, 0.02, 0.015, 1.0)
@export_range(0, 32, 1) var table_text_outline_size: int = 10
@export var table_text_shaded: bool = false
@export var table_text_no_depth_test: bool = true
@export var label_billboard_mode: int = 1

var table_layout_area: TableLayoutArea = null

func _ready() -> void:
	table_layout_area = get_node_or_null(table_layout_area_path) as TableLayoutArea

func clear_all_cards() -> void:
	for child: Node in get_children():
		child.queue_free()

func clear_group(group_id: StringName) -> void:
	for child: Node in get_children():
		if child.has_meta("table_card_group") and child.get_meta("table_card_group") == group_id:
			child.queue_free()

func show_card(card: Dictionary, group_id: StringName, position: Vector3, face_down: bool = false, rotation_y_degrees: float = 0.0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TableCard_%s" % String(group_id)
	root.position = _get_safe_local_position(position)
	root.rotation_degrees.y = rotation_y_degrees
	root.set_meta("table_card_group", group_id)
	add_child(root)

	if use_atlas_cards and card_atlas != null:
		var texture: Texture2D = card_atlas.get_back_texture() if face_down else card_atlas.get_card_texture(card)
		if texture != null:
			var sprite: Sprite3D = Sprite3D.new()
			sprite.name = "CardSprite"
			sprite.texture = texture
			sprite.pixel_size = _get_table_card_pixel_size()
			sprite.rotation_degrees.x = -90.0
			sprite.shaded = true
			sprite.no_depth_test = false
			root.add_child(sprite)
			return root

	var body: CSGBox3D = CSGBox3D.new()
	body.name = "CardBody"
	body.size = card_size
	body.material = _make_card_material(face_down)
	root.add_child(body)

	var label: Label3D = Label3D.new()
	label.name = "CardLabel"
	label.text = "★" if face_down else _get_card_text(card)
	label.font_size = label_font_size
	label.pixel_size = label_pixel_size
	label.position = Vector3(0.0, 0.055, 0.0)
	_style_table_label(label)
	root.add_child(label)
	return root

func show_stack(count: int, group_id: StringName, position: Vector3, face_down: bool = true, label_text: String = "") -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TableStack_%s" % String(group_id)
	root.position = _get_safe_local_position(position)
	root.set_meta("table_card_group", group_id)
	add_child(root)

	var shown_count: int = clampi(count, 0, visible_stack_cards)
	if count > 0 and shown_count <= 0:
		shown_count = 1

	for i: int in range(shown_count):
		var card_root: Node3D = Node3D.new()
		card_root.name = "StackCard_%02d" % i
		card_root.position = Vector3(float(i) * stack_spread, float(i) * stack_y_offset, float(i) * stack_spread)
		root.add_child(card_root)

		if use_atlas_cards and card_atlas != null:
			var texture: Texture2D = card_atlas.get_back_texture()
			if texture != null:
				var sprite: Sprite3D = Sprite3D.new()
				sprite.name = "StackCardSprite"
				sprite.texture = texture
				sprite.pixel_size = _get_table_card_pixel_size()
				sprite.rotation_degrees.x = -90.0
				sprite.shaded = true
				sprite.no_depth_test = false
				card_root.add_child(sprite)
				continue

		var body: CSGBox3D = CSGBox3D.new()
		body.name = "CardBody"
		body.size = card_size
		body.material = _make_card_material(face_down)
		card_root.add_child(body)

	if show_stack_labels and label_text != "":
		var label: Label3D = Label3D.new()
		label.name = "StackLabel"
		label.text = label_text
		label.font_size = label_font_size
		label.pixel_size = label_pixel_size
		label.position = stack_label_offset
		_style_table_label(label)
		root.add_child(label)
	return root

func _style_table_label(label: Label3D) -> void:
	if label == null:
		return
	label.modulate = table_text_color
	label.outline_modulate = table_text_outline_color
	label.outline_size = table_text_outline_size
	label.shaded = table_text_shaded
	label.no_depth_test = table_text_no_depth_test
	label.billboard = label_billboard_mode

func _get_safe_local_position(local_position: Vector3, margin: float = -1.0) -> Vector3:
	if not constrain_to_table_bounds:
		return local_position
	if table_layout_area == null:
		table_layout_area = get_node_or_null(table_layout_area_path) as TableLayoutArea
	if table_layout_area == null:
		return local_position
	var use_margin: float = card_bounds_margin if margin < 0.0 else margin
	var safe_global: Vector3 = table_layout_area.clamp_global_position(to_global(local_position), use_margin)
	return to_local(safe_global)

func _get_table_card_pixel_size() -> float:
	if card_atlas == null:
		return card_sprite_pixel_size
	var pixel_size: Vector2i = card_atlas.get_card_pixel_size()
	if pixel_size.x <= 0:
		return card_sprite_pixel_size
	return card_size.x / float(pixel_size.x)

func _make_card_material(face_down: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.28, 0.42, 1.0) if face_down else Color(0.88, 0.84, 0.68, 1.0)
	return material

func _get_card_text(card: Dictionary) -> String:
	if card.has("text"):
		return String(card["text"])
	return "%s%s" % [String(card.get("rank", "?")), String(card.get("suit", ""))]
