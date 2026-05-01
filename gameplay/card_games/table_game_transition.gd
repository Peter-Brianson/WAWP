extends Node
class_name TableGameTransition

signal transition_started(game_id: StringName)
signal game_started(game_id: StringName, game_node: Node)
signal game_finished(game_id: StringName, result: Dictionary)

@export_group("Scene Paths")
@export var camera_rig_path: NodePath = ^"../../World/CameraRig"
@export var active_game_root_path: NodePath = ^"../../World/StumpTableArea/CardGameRoot"
@export var fox_path: NodePath = ^"../../World/Animals/fox"
@export var human_boy_path: NodePath = ^"../../World/HumanBoy"
@export var player_hand_ui_path: NodePath = ^"../../CanvasLayer/PlayerHandUI"
@export var table_card_renderer_path: NodePath = ^"../../World/StumpTableArea/TableCardRenderer"
@export var win_popup_ui_path: NodePath = ^"../../CanvasLayer/WinPopupUI"
@export var table_layout_area_path: NodePath = ^"../../World/StumpTableArea/TableLayoutArea"
@export var table_dialogue_ui_path: NodePath = ^"../../CanvasLayer/TableDialogueUI"

@export_group("Dialogue Anchors")
@export var fox_dialogue_anchor_path: NodePath = ^"../../World/Animals/fox/DialogueAnchor"
@export var human_dialogue_anchor_path: NodePath = ^"../../World/HumanBoy/DialogueAnchor"

@export_group("Seat Markers")
@export var center_deck_marker_path: NodePath = ^"../../World/StumpTableArea/SeatAnchors/CenterDeck"
@export var player_seat_marker_path: NodePath = ^"../../World/StumpTableArea/SeatAnchors/PlayerSeat"
@export var fox_seat_marker_path: NodePath = ^"../../World/StumpTableArea/SeatAnchors/FoxSeat"

@export_group("Camera")
@export var table_camera_position: Vector3 = Vector3(0.0, 3.2, 1.2)
@export var table_camera_rotation_degrees: Vector3 = Vector3(-72.0, 0.0, 0.0)
@export_range(0.05, 5.0, 0.05) var camera_move_time: float = 0.75

@export_group("Gathering")
@export var gather_players: bool = true
@export_range(0.05, 5.0, 0.05) var gather_time: float = 0.45
@export var fallback_player_seat_local: Vector3 = Vector3(0.0, 0.32, 0.65)
@export var fallback_fox_seat_local: Vector3 = Vector3(0.0, 0.32, -0.65)
@export var fallback_center_deck_local: Vector3 = Vector3(0.0, 0.32, 0.0)

@export_group("Post Game")
@export_range(0.0, 5.0, 0.1) var post_game_hold_time: float = 1.2
@export var reset_camera_after_game: bool = true
@export_range(0.05, 5.0, 0.05) var camera_return_time: float = 0.65

var active_game: Node = null
var active_game_id: StringName = &""
var transition_running: bool = false

var _saved_camera_position: Vector3 = Vector3.ZERO
var _saved_camera_rotation_degrees: Vector3 = Vector3.ZERO
var _has_saved_camera_transform: bool = false


func start_card_game(entry: BookGameEntry) -> void:
	if entry == null:
		push_warning("TableGameTransition.start_card_game called with null entry.")
		return

	if entry.minigame_scene == null:
		push_warning("BookGameEntry '%s' has no minigame_scene assigned." % String(entry.game_id))
		return

	if transition_running:
		return

	transition_running = true
	active_game_id = entry.game_id

	transition_started.emit(active_game_id)

	clear_active_game()
	_cache_camera_home_transform()

	await _move_camera_to_table()
	await _gather_players_to_table()

	_load_game(entry)

	transition_running = false


func debug_end_active_game(winner_id: StringName = &"fox") -> void:
	if active_game == null or not is_instance_valid(active_game):
		return

	if active_game.has_method("debug_end_test"):
		active_game.call("debug_end_test", winner_id)
		return

	var result: Dictionary = {
		"game_id": active_game_id,
		"winner_id": winner_id,
		"summary": "Debug ended.",
		"felt_slow": false,
		"stalemate": false,
		"boredom_delta": 0
	}

	if active_game.has_signal("game_finished"):
		active_game.emit_signal("game_finished", result)


func _cache_camera_home_transform() -> void:
	var camera_rig := get_node_or_null(camera_rig_path) as Node3D
	if camera_rig == null:
		return

	_saved_camera_position = camera_rig.position
	_saved_camera_rotation_degrees = camera_rig.rotation_degrees
	_has_saved_camera_transform = true


func _return_camera_home() -> void:
	if not reset_camera_after_game:
		return

	if not _has_saved_camera_transform:
		return

	var camera_rig := get_node_or_null(camera_rig_path) as Node3D
	if camera_rig == null:
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera_rig, "position", _saved_camera_position, camera_return_time)
	tween.tween_property(camera_rig, "rotation_degrees", _saved_camera_rotation_degrees, camera_return_time)

	await tween.finished


func clear_active_game() -> void:
	if active_game != null and is_instance_valid(active_game):
		active_game.queue_free()

	active_game = null

	var table_renderer := get_node_or_null(table_card_renderer_path)
	if table_renderer != null and table_renderer.has_method("clear_all_cards"):
		table_renderer.call("clear_all_cards")


func _move_camera_to_table() -> void:
	var camera_rig := get_node_or_null(camera_rig_path) as Node3D

	if camera_rig == null:
		push_warning("TableGameTransition could not find CameraRig.")
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(camera_rig, "position", table_camera_position, camera_move_time)
	tween.tween_property(camera_rig, "rotation_degrees", table_camera_rotation_degrees, camera_move_time)

	await tween.finished


func _gather_players_to_table() -> void:
	if not gather_players:
		return

	var tween := create_tween()
	tween.set_parallel(true)

	var did_tween := false

	var fox := get_node_or_null(fox_path) as Node3D
	if fox != null:
		tween.tween_property(fox, "global_position", _get_marker_global_position(fox_seat_marker_path, fallback_fox_seat_local), gather_time)
		did_tween = true

	var human_boy := get_node_or_null(human_boy_path) as Node3D
	if human_boy != null:
		tween.tween_property(human_boy, "global_position", _get_marker_global_position(player_seat_marker_path, fallback_player_seat_local), gather_time)
		did_tween = true

	if did_tween:
		await tween.finished


func _load_game(entry: BookGameEntry) -> void:
	var active_root := get_node_or_null(active_game_root_path)

	if active_root == null:
		push_warning("TableGameTransition could not find CardGameRoot. Loading game under transition node.")
		active_root = self

	active_game = entry.minigame_scene.instantiate()
	active_root.add_child(active_game)

	if active_game.has_signal("game_finished"):
		active_game.connect("game_finished", Callable(self, "_on_active_game_finished"))

	if active_game.has_method("configure_card_game"):
		active_game.call("configure_card_game", _build_game_context())

	if active_game.has_method("start_game"):
		active_game.call("start_game")

	game_started.emit(active_game_id, active_game)


func _build_game_context() -> Dictionary:
	var human_anchor: Node = get_node_or_null(human_dialogue_anchor_path)
	var fox_anchor: Node = get_node_or_null(fox_dialogue_anchor_path)

	return {
		"game_id": active_game_id,
		"center_deck_global": _get_marker_global_position(center_deck_marker_path, fallback_center_deck_local),
		"player_seat_global": _get_marker_global_position(player_seat_marker_path, fallback_player_seat_local),
		"fox_seat_global": _get_marker_global_position(fox_seat_marker_path, fallback_fox_seat_local),
		"player_ids": [&"player", &"fox"],
		"player_hand_ui": get_node_or_null(player_hand_ui_path),
		"table_card_renderer": get_node_or_null(table_card_renderer_path),
		"table_layout_area": get_node_or_null(table_layout_area_path),
		"table_dialogue_ui": get_node_or_null(table_dialogue_ui_path),
		"dialogue_anchors": {
			&"fox": fox_anchor,
			&"player": human_anchor,
			&"human": human_anchor,
			&"human_boy": human_anchor
		}
	}


func _get_marker_global_position(marker_path: NodePath, fallback_local: Vector3) -> Vector3:
	var marker := get_node_or_null(marker_path) as Node3D

	if marker != null:
		return marker.global_position

	var active_root := get_node_or_null(active_game_root_path) as Node3D

	if active_root != null:
		return active_root.to_global(fallback_local)

	return fallback_local


func _on_active_game_finished(result: Dictionary = {}) -> void:
	await _show_win_popup(result)

	clear_active_game()

	await _return_camera_home()

	game_finished.emit(active_game_id, result)


func _show_win_popup(result: Dictionary) -> void:
	var win_popup: WinPopupUI = get_node_or_null(win_popup_ui_path) as WinPopupUI

	if win_popup == null:
		if post_game_hold_time > 0.0:
			await get_tree().create_timer(post_game_hold_time).timeout
		return

	win_popup.show_result(active_game_id, result)
	await win_popup.next_requested
