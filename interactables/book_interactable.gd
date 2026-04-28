extends Node3D
class_name BookInteractable

signal focus_entered(book: BookInteractable)
signal focus_exited(book: BookInteractable)
signal open_book_requested(book: BookInteractable)

@export_group("Interaction")
@export var enabled: bool = true
@export var prompt_text: String = "Read Book"
@export var confirm_action: StringName = &"ui_accept"
@export var open_on_first_click: bool = true
@export var allow_keyboard_confirm_when_focused: bool = true

@export_group("Visual Feedback")
@export var focused_scale: Vector3 = Vector3(1.05, 1.05, 1.05)
@export var use_hover_motion: bool = true
@export_range(0.0, 0.25, 0.005) var hover_amount: float = 0.025
@export_range(0.1, 8.0, 0.1) var hover_speed: float = 2.0

@export_group("Audio")
@export var focus_sfx: AudioStream
@export var open_sfx: AudioStream

@onready var visual_root: Node3D = $VisualRoot
@onready var click_target: Area3D = $ClickTarget
@onready var selection_root: Node3D = $SelectionRoot
@onready var prompt_label: Label3D = $SelectionRoot/PromptLabel3D
@onready var sfx_player: AudioStreamPlayer3D = $SFXPlayer

var is_focused: bool = false
var _base_visual_position: Vector3
var _base_visual_scale: Vector3
var _time: float = 0.0


func _ready() -> void:
	_base_visual_position = visual_root.position
	_base_visual_scale = visual_root.scale

	click_target.input_ray_pickable = true

	if not click_target.input_event.is_connected(_on_click_target_input_event):
		click_target.input_event.connect(_on_click_target_input_event)

	if not click_target.mouse_entered.is_connected(_on_click_target_mouse_entered):
		click_target.mouse_entered.connect(_on_click_target_mouse_entered)

	if not click_target.mouse_exited.is_connected(_on_click_target_mouse_exited):
		click_target.mouse_exited.connect(_on_click_target_mouse_exited)

	if selection_root != null:
		selection_root.visible = false

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false


func _process(delta: float) -> void:
	if not enabled:
		return

	_update_hover(delta)

	if allow_keyboard_confirm_when_focused:
		if is_focused and Input.is_action_just_pressed(confirm_action):
			open_book()


func _on_click_target_input_event(
	camera: Camera3D,
	event: InputEvent,
	event_position: Vector3,
	normal: Vector3,
	shape_idx: int
) -> void:
	if not enabled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			_handle_pointer_pressed()

	if event is InputEventScreenTouch:
		if event.pressed:
			accept_event()
			_handle_pointer_pressed()


func _on_click_target_mouse_entered() -> void:
	if not enabled:
		return

	set_focused(true)


func _on_click_target_mouse_exited() -> void:
	if not enabled:
		return

	if not open_on_first_click:
		return

	set_focused(false)


func _handle_pointer_pressed() -> void:
	if not is_focused:
		set_focused(true)

	if open_on_first_click:
		open_book()


func set_focused(value: bool) -> void:
	if is_focused == value:
		return

	is_focused = value

	if visual_root != null:
		visual_root.scale = focused_scale if is_focused else _base_visual_scale

	if selection_root != null:
		selection_root.visible = is_focused

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = is_focused

	if is_focused:
		_play_sfx(focus_sfx)
		focus_entered.emit(self)
	else:
		focus_exited.emit(self)


func open_book() -> void:
	if not enabled:
		return

	_play_sfx(open_sfx)
	open_book_requested.emit(self)


func set_enabled(value: bool) -> void:
	enabled = value

	if click_target != null:
		click_target.input_ray_pickable = enabled

	if not enabled:
		set_focused(false)


func _update_hover(delta: float) -> void:
	if not use_hover_motion:
		return

	if visual_root == null:
		return

	_time += delta

	if is_focused:
		var hover_y := sin(_time * hover_speed) * hover_amount
		visual_root.position = _base_visual_position + Vector3(0.0, hover_y, 0.0)
	else:
		visual_root.position = _base_visual_position


func _play_sfx(stream: AudioStream) -> void:
	if sfx_player == null:
		return

	if stream == null:
		return

	sfx_player.stream = stream
	sfx_player.play()
