@tool
extends Node3D
class_name TableLayoutArea

@export_group("Table Bounds")
@export var half_extents: Vector2 = Vector2(0.62, 0.46)
@export var table_y: float = 0.36
@export_range(0.0, 0.25, 0.005) var edge_padding: float = 0.06

@export_group("Layout Spacing")
@export var card_spacing: float = 0.18
@export var stack_margin: float = 0.09
@export var player_zone_radius: Vector2 = Vector2(0.44, 0.31)

@export_group("Debug")
@export var show_debug_bounds: bool = true:
	set(value):
		show_debug_bounds = value
		if is_inside_tree():
			_update_debug_bounds()

@export var debug_color: Color = Color(0.1, 0.9, 1.0, 0.35)

var _debug_mesh: MeshInstance3D = null


func _ready() -> void:
	_update_debug_bounds()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_update_debug_bounds()


func clamp_global_position(_global_position: Vector3, margin: float = 0.0) -> Vector3:
	var local_position: Vector3 = to_local(_global_position)
	var safe_margin: float = edge_padding + margin

	local_position.x = clampf(
		local_position.x,
		-half_extents.x + safe_margin,
		half_extents.x - safe_margin
	)

	local_position.z = clampf(
		local_position.z,
		-half_extents.y + safe_margin,
		half_extents.y - safe_margin
	)

	return to_global(local_position)


func clamp_local_position(local_position: Vector3, margin: float = 0.0) -> Vector3:
	var safe_margin: float = edge_padding + margin

	local_position.x = clampf(
		local_position.x,
		-half_extents.x + safe_margin,
		half_extents.x - safe_margin
	)

	local_position.z = clampf(
		local_position.z,
		-half_extents.y + safe_margin,
		half_extents.y - safe_margin
	)

	return local_position


func get_center_global() -> Vector3:
	return to_global(Vector3(0.0, table_y, 0.0))


func get_deck_global() -> Vector3:
	return to_global(clamp_local_position(Vector3(half_extents.x * 0.55, table_y, 0.0), stack_margin))


func get_pot_global() -> Vector3:
	return to_global(clamp_local_position(Vector3(0.0, table_y, -half_extents.y * 0.22), stack_margin))


func get_community_card_global(index: int, total_cards: int) -> Vector3:
	var count: int = maxi(total_cards, 1)
	var total_width: float = card_spacing * float(count - 1)
	var start_x: float = -total_width * 0.5
	var x: float = start_x + card_spacing * float(index)
	var local_position: Vector3 = Vector3(x, table_y, 0.0)
	return to_global(clamp_local_position(local_position, stack_margin))


func get_player_zone_global(player_index: int, total_players: int, inward_offset: float = 0.0) -> Vector3:
	var count: int = maxi(total_players, 1)

	if count == 2:
		if player_index == 0:
			return to_global(clamp_local_position(Vector3(0.0, table_y, half_extents.y * 0.66 - inward_offset), stack_margin))
		return to_global(clamp_local_position(Vector3(0.0, table_y, -half_extents.y * 0.66 + inward_offset), stack_margin))

	var angle: float = PI * 0.5 + TAU * (float(player_index) / float(count))
	var x: float = cos(angle) * maxf(player_zone_radius.x - inward_offset, 0.05)
	var z: float = sin(angle) * maxf(player_zone_radius.y - inward_offset, 0.05)

	return to_global(clamp_local_position(Vector3(x, table_y, z), stack_margin))


func get_player_stack_global(player_index: int, total_players: int) -> Vector3:
	return get_player_zone_global(player_index, total_players, 0.06)


func get_player_face_up_global(player_index: int, total_players: int) -> Vector3:
	return get_player_zone_global(player_index, total_players, 0.18)


func get_offset_global(base_global: Vector3, local_offset: Vector3, margin: float = 0.0) -> Vector3:
	var base_local: Vector3 = to_local(base_global)
	var target_local: Vector3 = base_local + local_offset
	return to_global(clamp_local_position(target_local, margin))


func _update_debug_bounds() -> void:
	if not show_debug_bounds:
		if _debug_mesh != null:
			_debug_mesh.visible = false
		return

	if _debug_mesh == null:
		_debug_mesh = get_node_or_null("DebugBounds") as MeshInstance3D

	if _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.name = "DebugBounds"
		add_child(_debug_mesh)

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(half_extents.x * 2.0, 0.01, half_extents.y * 2.0)
	_debug_mesh.mesh = box_mesh
	_debug_mesh.position = Vector3(0.0, table_y - 0.012, 0.0)
	_debug_mesh.visible = show_debug_bounds

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = debug_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mesh.material_override = material
