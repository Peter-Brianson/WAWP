extends Node3D
class_name TableCardRenderer

signal table_piece_clicked(group_id: StringName, piece: Node3D, event: InputEvent)

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
@export var stack_label_offset: Vector3 = Vector3(0.0, 0.24, 0.0)

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
@export var table_text_fixed_size: bool = false
@export var label_billboard_mode: int = 1

@export_group("3D Draw Priority")
@export var card_sprite_render_priority: int = -20
@export var label_render_priority: int = 100
@export var force_label_depth_overlay: bool = true

@export_group("Click Targets")
@export var add_click_targets: bool = true
@export var click_target_height: float = 0.10
@export var click_target_scale: Vector2 = Vector2(1.25, 1.25)

@export_group("Interaction Feedback")
@export var enable_interaction_glow: bool = true
@export var interaction_glow_size: Vector2 = Vector2(0.28, 0.38)
@export var interaction_glow_color: Color = Color(1.0, 0.88, 0.28, 0.38)
@export var interaction_glow_height: float = 0.006
@export var spark_on_click: bool = true
@export_range(0.05, 1.0, 0.01) var spark_lifetime: float = 0.32

var table_layout_area: Node = null


func _ready() -> void:
	table_layout_area = get_node_or_null(table_layout_area_path)


func clear_all_cards() -> void:
	for child: Node in get_children():
		child.queue_free()


func clear_group(group_id: StringName) -> void:
	for child: Node in get_children():
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
	root.position = _get_safe_local_position(position)
	root.rotation_degrees.y = rotation_y_degrees
	root.set_meta("table_card_group", group_id)
	add_child(root)

	if use_atlas_cards and card_atlas != null:
		var texture: Texture2D = null

		if face_down:
			texture = card_atlas.get_back_texture()
		else:
			texture = card_atlas.get_card_texture(card)

		if texture != null:
			var sprite: Sprite3D = Sprite3D.new()
			sprite.name = "CardSprite"
			sprite.texture = texture
			sprite.pixel_size = _get_table_card_pixel_size()
			sprite.rotation_degrees.x = -90.0
			_style_card_sprite(sprite)
			root.add_child(sprite)
			_add_click_target(root, group_id, 1)
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
	label.position = Vector3(0.0, 0.075, 0.0)
	_style_table_label(label)
	root.add_child(label)

	_add_click_target(root, group_id, 1)
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
	root.position = _get_safe_local_position(position)
	root.set_meta("table_card_group", group_id)
	add_child(root)

	var shown_count: int = clampi(count, 0, visible_stack_cards)

	if count > 0 and shown_count <= 0:
		shown_count = 1

	for i: int in range(shown_count):
		var card_root: Node3D = Node3D.new()
		card_root.name = "StackCard_%02d" % i
		card_root.position = Vector3(
			float(i) * stack_spread,
			float(i) * stack_y_offset,
			float(i) * stack_spread
		)
		root.add_child(card_root)

		if use_atlas_cards and card_atlas != null:
			var texture: Texture2D = card_atlas.get_back_texture()

			if texture != null:
				var sprite: Sprite3D = Sprite3D.new()
				sprite.name = "StackCardSprite"
				sprite.texture = texture
				sprite.pixel_size = _get_table_card_pixel_size()
				sprite.rotation_degrees.x = -90.0
				_style_card_sprite(sprite)
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

	_add_click_target(root, group_id, shown_count)
	return root


func _add_click_target(root: Node3D, group_id: StringName, stack_count: int = 1) -> void:
	if not add_click_targets:
		return

	if root == null:
		return

	var area: Area3D = Area3D.new()
	area.name = "ClickTarget"
	area.input_ray_pickable = true
	area.monitoring = true
	area.monitorable = true
	root.add_child(area)

	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"

	var box: BoxShape3D = BoxShape3D.new()
	var spread_bonus: float = float(maxi(stack_count - 1, 0)) * stack_spread
	box.size = Vector3(
		(card_size.x + spread_bonus) * click_target_scale.x,
		click_target_height,
		(card_size.z + spread_bonus) * click_target_scale.y
	)

	shape.shape = box
	shape.position = Vector3(0.0, click_target_height * 0.5, 0.0)
	area.add_child(shape)

	if enable_interaction_glow:
		_add_interaction_glow(root)

	area.mouse_entered.connect(_on_click_target_mouse_entered.bind(root))
	area.mouse_exited.connect(_on_click_target_mouse_exited.bind(root))
	area.input_event.connect(_on_click_target_input_event.bind(group_id, root))


func _on_click_target_input_event(
	camera: Camera3D,
	event: InputEvent,
	event_position: Vector3,
	normal: Vector3,
	shape_idx: int,
	group_id: StringName,
	piece: Node3D
) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if spark_on_click:
				_spawn_click_spark(piece.global_position)
			table_piece_clicked.emit(group_id, piece, event)

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			if spark_on_click:
				_spawn_click_spark(piece.global_position)
			table_piece_clicked.emit(group_id, piece, event)


func _add_interaction_glow(root: Node3D) -> void:
	if root == null:
		return

	if root.get_node_or_null("InteractionGlow") != null:
		return

	var glow: MeshInstance3D = MeshInstance3D.new()
	glow.name = "InteractionGlow"
	glow.visible = false
	glow.position = Vector3(0.0, interaction_glow_height, 0.0)
	glow.rotation_degrees.x = -90.0

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = interaction_glow_size
	glow.mesh = plane

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = interaction_glow_color
	material.emission_enabled = true
	material.emission = Color(interaction_glow_color.r, interaction_glow_color.g, interaction_glow_color.b)
	material.emission_energy_multiplier = 0.45
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true

	glow.material_override = material
	root.add_child(glow)


func _on_click_target_mouse_entered(root: Node3D) -> void:
	if root == null:
		return

	var glow: MeshInstance3D = root.get_node_or_null("InteractionGlow") as MeshInstance3D
	if glow != null:
		glow.visible = true


func _on_click_target_mouse_exited(root: Node3D) -> void:
	if root == null:
		return

	var glow: MeshInstance3D = root.get_node_or_null("InteractionGlow") as MeshInstance3D
	if glow != null:
		glow.visible = false


func _spawn_click_spark(global_position: Vector3) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = self

	var spark_root: Node3D = Node3D.new()
	spark_root.name = "ClickSpark"
	scene_root.add_child(spark_root)
	spark_root.global_position = global_position + Vector3(0.0, 0.08, 0.0)

	for i: int in range(6):
		var spark: MeshInstance3D = MeshInstance3D.new()
		spark.name = "Spark_%02d" % i

		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.012
		sphere.height = 0.024
		spark.mesh = sphere

		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.86, 0.32, 1.0)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.72, 0.20, 1.0)
		material.emission_energy_multiplier = 0.8
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.material_override = material

		spark_root.add_child(spark)

		var angle: float = TAU * (float(i) / 6.0)
		var target: Vector3 = Vector3(cos(angle) * 0.08, 0.08, sin(angle) * 0.08)

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", target, spark_lifetime * 0.875)
		tween.tween_property(spark, "scale", Vector3.ZERO, spark_lifetime * 0.875)

	var cleanup_tween: Tween = create_tween()
	cleanup_tween.tween_interval(spark_lifetime)
	cleanup_tween.tween_callback(spark_root.queue_free)


func _style_card_sprite(sprite: Sprite3D) -> void:
	if sprite == null:
		return

	sprite.shaded = true
	sprite.no_depth_test = false
	sprite.render_priority = card_sprite_render_priority
	sprite.alpha_cut = 0


func _style_table_label(label: Label3D) -> void:
	if label == null:
		return

	label.modulate = table_text_color
	label.outline_modulate = table_text_outline_color
	label.outline_size = table_text_outline_size
	label.no_depth_test = force_label_depth_overlay or table_text_no_depth_test
	label.shaded = table_text_shaded
	label.fixed_size = table_text_fixed_size
	label.billboard = label_billboard_mode
	label.render_priority = label_render_priority
	label.alpha_cut = 0


func _get_safe_local_position(local_position: Vector3, margin: float = -1.0) -> Vector3:
	if not constrain_to_table_bounds:
		return local_position

	if table_layout_area == null:
		table_layout_area = get_node_or_null(table_layout_area_path)

	if table_layout_area == null:
		return local_position

	if not table_layout_area.has_method("clamp_global_position"):
		return local_position

	var use_margin: float = card_bounds_margin if margin < 0.0 else margin
	var global_position: Vector3 = to_global(local_position)
	var safe_global_variant: Variant = table_layout_area.call("clamp_global_position", global_position, use_margin)

	if safe_global_variant is Vector3:
		var safe_global: Vector3 = safe_global_variant
		return to_local(safe_global)

	return local_position


func _get_table_card_pixel_size() -> float:
	if card_atlas == null:
		return card_sprite_pixel_size

	var pixel_size: Vector2i = card_atlas.get_card_pixel_size()

	if pixel_size.x <= 0:
		return card_sprite_pixel_size

	return card_size.x / float(pixel_size.x)


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
