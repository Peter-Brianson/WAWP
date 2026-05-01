@tool
extends Node3D

enum CanopyShape {
	ROUND,
	OVAL,
	WIDE_DOME,
	PINE,
	LAYERED
}

const GENERATED_PREFIX := "_generated_"

@export_category("Build")
@export var rebuild_tree := false:
	set(value):
		rebuild_tree = false
		if value:
			call_deferred("_rebuild_tree")

@export var auto_build_on_ready := true

@export_category("Tree Shape")
@export var random_seed: int = 12345
@export var canopy_shape: CanopyShape = CanopyShape.ROUND
@export_range(8, 600, 1) var leaf_card_count: int = 180
@export_range(0.5, 8.0, 0.05) var trunk_height: float = 2.4
@export_range(0.05, 1.0, 0.01) var trunk_bottom_radius: float = 0.25
@export_range(0.01, 0.8, 0.01) var trunk_top_radius: float = 0.14

@export_range(0.5, 8.0, 0.05) var canopy_radius: float = 1.8
@export_range(0.5, 6.0, 0.05) var canopy_height: float = 1.8
@export_range(-2.0, 4.0, 0.05) var canopy_y_offset: float = 0.8
@export_range(0.25, 3.0, 0.05) var canopy_x_scale: float = 1.0
@export_range(0.25, 3.0, 0.05) var canopy_z_scale: float = 1.0

@export_category("Leaf Card Shape")
@export_range(0.05, 2.0, 0.01) var leaf_card_width: float = 0.55
@export_range(0.05, 2.0, 0.01) var leaf_card_height: float = 0.42
@export_range(0.0, 1.0, 0.01) var leaf_size_randomness: float = 0.35
@export_range(0.0, 1.0, 0.01) var leaf_position_randomness: float = 0.25
@export_range(0.0, 90.0, 1.0) var leaf_max_tilt_degrees: float = 22.0

@export_category("Colors")
@export var trunk_color: Color = Color(0.45, 0.25, 0.12, 1.0)
@export var trunk_shadow_color: Color = Color(0.24, 0.13, 0.07, 1.0)

@export var leaf_top_color: Color = Color(0.78, 0.92, 0.43, 1.0)
@export var leaf_mid_color: Color = Color(0.38, 0.68, 0.28, 1.0)
@export var leaf_shadow_color: Color = Color(0.12, 0.34, 0.18, 1.0)
@export_range(0.0, 0.5, 0.01) var leaf_color_variation: float = 0.12

@export_category("Wind")
@export var wind_enabled := true
@export_range(0.0, 0.5, 0.005) var wind_strength: float = 0.035
@export_range(0.0, 8.0, 0.05) var wind_speed: float = 1.2

@export_category("Debug")
@export var show_generated_names := false


func _ready() -> void:
	if auto_build_on_ready:
		_rebuild_tree()


func _rebuild_tree() -> void:
	if not is_inside_tree():
		return

	_clear_generated_children()

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	_create_trunk()
	_create_leaf_canopy(rng)


func _clear_generated_children() -> void:
	for child in get_children():
		if child.name.begins_with(GENERATED_PREFIX):
			remove_child(child)
			child.queue_free()


func _create_trunk() -> void:
	var trunk := MeshInstance3D.new()
	trunk.name = GENERATED_PREFIX + "trunk" if show_generated_names else GENERATED_PREFIX + "Tree Trunk"

	var mesh := CylinderMesh.new()
	mesh.height = trunk_height
	mesh.bottom_radius = trunk_bottom_radius
	mesh.top_radius = trunk_top_radius
	mesh.radial_segments = 8
	mesh.rings = 3

	trunk.mesh = mesh
	trunk.position.y = trunk_height * 0.5
	trunk.material_override = _make_trunk_material()

	add_child(trunk)
	_set_owner_for_editor(trunk)


func _create_leaf_canopy(rng: RandomNumberGenerator) -> void:
	var canopy := MultiMeshInstance3D.new()
	canopy.name = GENERATED_PREFIX + "canopy" if show_generated_names else GENERATED_PREFIX + "Leaf Canopy"

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = leaf_card_count

	var canopy_center := Vector3(0.0, trunk_height + canopy_y_offset, 0.0)

	for i in leaf_card_count:
		var local_pos := _get_canopy_local_position(rng)
		var world_pos := canopy_center + local_pos

		var yaw := rng.randf_range(0.0, TAU)
		var pitch := deg_to_rad(rng.randf_range(-leaf_max_tilt_degrees, leaf_max_tilt_degrees))
		var roll := deg_to_rad(rng.randf_range(-leaf_max_tilt_degrees, leaf_max_tilt_degrees))

		var basis := Basis()
		basis = basis.rotated(Vector3.UP, yaw)
		basis = basis.rotated(Vector3.RIGHT, pitch)
		basis = basis.rotated(Vector3.FORWARD, roll)

		var size_random := 1.0 + rng.randf_range(-leaf_size_randomness, leaf_size_randomness)
		var width := leaf_card_width * size_random
		var height := leaf_card_height * size_random

		basis = basis.scaled(Vector3(width, height, 1.0))

		var transform := Transform3D(basis, world_pos)
		multimesh.set_instance_transform(i, transform)

		# INSTANCE_CUSTOM:
		# x = color variation
		# y = wind phase
		# z = unused
		# w = unused
		var custom := Color(
			rng.randf_range(-leaf_color_variation, leaf_color_variation),
			rng.randf(),
			0.0,
			1.0
		)

		multimesh.set_instance_custom_data(i, custom)

	canopy.multimesh = multimesh
	canopy.material_override = _make_leaf_material()

	add_child(canopy)
	_set_owner_for_editor(canopy)


func _get_canopy_local_position(rng: RandomNumberGenerator) -> Vector3:
	match canopy_shape:
		CanopyShape.ROUND:
			return _sample_round_canopy(rng)

		CanopyShape.OVAL:
			return _sample_round_canopy(rng) * Vector3(canopy_x_scale * 1.35, 0.85, canopy_z_scale)

		CanopyShape.WIDE_DOME:
			return _sample_wide_dome_canopy(rng)

		CanopyShape.PINE:
			return _sample_pine_canopy(rng)

		CanopyShape.LAYERED:
			return _sample_layered_canopy(rng)

	return _sample_round_canopy(rng)


func _sample_round_canopy(rng: RandomNumberGenerator) -> Vector3:
	var dir := _random_unit_vector(rng)
	var distance := pow(rng.randf(), 0.55)

	var pos := Vector3(
		dir.x * canopy_radius * canopy_x_scale,
		dir.y * canopy_height * 0.5,
		dir.z * canopy_radius * canopy_z_scale
	) * distance

	pos += _small_random_offset(rng)
	return pos


func _sample_wide_dome_canopy(rng: RandomNumberGenerator) -> Vector3:
	var angle: float = rng.randf_range(0.0, TAU)
	var radius_factor: float = sqrt(rng.randf())
	var y_factor: float = rng.randf()

	var dome_radius: float = canopy_radius * (1.0 - y_factor * 0.35)

	var x: float = cos(angle) * dome_radius * radius_factor * canopy_x_scale * 1.35
	var z: float = sin(angle) * dome_radius * radius_factor * canopy_z_scale * 1.15
	var y: float = lerpf(-canopy_height * 0.35, canopy_height * 0.55, y_factor)

	var pos: Vector3 = Vector3(x, y, z)
	pos += _small_random_offset(rng)
	return pos


func _sample_pine_canopy(rng: RandomNumberGenerator) -> Vector3:
	var y_factor: float = rng.randf()
	var angle: float = rng.randf_range(0.0, TAU)

	var layer_radius: float = canopy_radius * (1.0 - y_factor)
	layer_radius = maxf(layer_radius, canopy_radius * 0.12)

	var radius_factor: float = sqrt(rng.randf())
	var x: float = cos(angle) * layer_radius * radius_factor * canopy_x_scale
	var z: float = sin(angle) * layer_radius * radius_factor * canopy_z_scale
	var y: float = lerpf(-canopy_height * 0.45, canopy_height * 0.65, y_factor)

	var pos: Vector3 = Vector3(x, y, z)
	pos += _small_random_offset(rng)
	return pos


func _sample_layered_canopy(rng: RandomNumberGenerator) -> Vector3:
	var layer_count: int = 4
	var layer: int = rng.randi_range(0, layer_count - 1)
	var layer_t: float = float(layer) / float(layer_count - 1)

	var layer_y: float = lerpf(-canopy_height * 0.35, canopy_height * 0.5, layer_t)
	var layer_radius: float = canopy_radius * lerpf(1.1, 0.55, layer_t)

	var angle: float = rng.randf_range(0.0, TAU)
	var radius_factor: float = sqrt(rng.randf())

	var x: float = cos(angle) * layer_radius * radius_factor * canopy_x_scale
	var z: float = sin(angle) * layer_radius * radius_factor * canopy_z_scale
	var y: float = layer_y + rng.randf_range(-0.18, 0.18)

	var pos: Vector3 = Vector3(x, y, z)
	pos += _small_random_offset(rng)
	return pos


func _random_unit_vector(rng: RandomNumberGenerator) -> Vector3:
	var v := Vector3.ZERO

	while v.length_squared() < 0.001:
		v = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		)

	return v.normalized()


func _small_random_offset(rng: RandomNumberGenerator) -> Vector3:
	return Vector3(
		rng.randf_range(-leaf_position_randomness, leaf_position_randomness),
		rng.randf_range(-leaf_position_randomness, leaf_position_randomness),
		rng.randf_range(-leaf_position_randomness, leaf_position_randomness)
	)


func _make_trunk_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = trunk_color
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _make_leaf_material() -> ShaderMaterial:
	var shader := Shader.new()

	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 leaf_top_color : source_color = vec4(0.78, 0.92, 0.43, 1.0);
uniform vec4 leaf_mid_color : source_color = vec4(0.38, 0.68, 0.28, 1.0);
uniform vec4 leaf_shadow_color : source_color = vec4(0.12, 0.34, 0.18, 1.0);

uniform bool wind_enabled = true;
uniform float wind_strength = 0.035;
uniform float wind_speed = 1.2;

varying float leaf_variation;

void vertex() {
	leaf_variation = INSTANCE_CUSTOM.x;

	if (wind_enabled) {
		float phase = INSTANCE_CUSTOM.y * 6.28318;
		float sway = sin(TIME * wind_speed + phase + VERTEX.y * 2.0) * wind_strength;
		VERTEX.x += sway * (0.25 + UV.y);
	}
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;

	// Turns the square card into a soft oval/leaf blob.
	float oval = dot(centered_uv, centered_uv);
	float mask = smoothstep(1.0, 0.72, oval);

	if (mask < 0.35) {
		discard;
	}

	// Simple vertical anime-style color banding.
	vec3 lower = mix(leaf_shadow_color.rgb, leaf_mid_color.rgb, smoothstep(0.0, 0.65, UV.y));
	vec3 upper = mix(lower, leaf_top_color.rgb, smoothstep(0.55, 1.0, UV.y));

	vec3 final_color = upper + vec3(leaf_variation);
	ALBEDO = clamp(final_color, vec3(0.0), vec3(1.0));
	ALPHA = mask;
}
"""

	var mat := ShaderMaterial.new()
	mat.shader = shader

	mat.set_shader_parameter("leaf_top_color", leaf_top_color)
	mat.set_shader_parameter("leaf_mid_color", leaf_mid_color)
	mat.set_shader_parameter("leaf_shadow_color", leaf_shadow_color)
	mat.set_shader_parameter("wind_enabled", wind_enabled)
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("wind_speed", wind_speed)

	return mat


func _set_owner_for_editor(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	if get_tree() == null:
		return

	var scene_root := get_tree().edited_scene_root
	if scene_root == null:
		return

	node.owner = scene_root
