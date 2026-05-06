extends Node3D
class_name BookInteractable

signal focused(book: BookInteractable)
signal unfocused(book: BookInteractable)
signal open_requested(book: BookInteractable)

@export_group("Interaction")
@export var enabled: bool = true
@export var prompt_text: String = "Read Book"
@export var confirm_action: StringName = &"ui_accept"
@export var open_on_click: bool = true
@export var allow_confirm_when_focused: bool = true

@export_group("Visual Feedback")
@export var focused_scale: Vector3 = Vector3(1.05, 1.05, 1.05)
@export var use_hover_motion: bool = true
@export_range(0.0, 0.25, 0.005) var hover_amount: float = 0.025
@export_range(0.1, 8.0, 0.1) var hover_speed: float = 2.0

@export_group("Audio")
@export var focus_sfx: AudioStream
@export var open_sfx: AudioStream

@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var click_target: Area3D = get_node_or_null("ClickTarget") as Area3D
@onready var selection_root: Node3D = get_node_or_null("SelectionRoot") as Node3D
@onready var prompt_label: Label3D = get_node_or_null("SelectionRoot/PromptLabel3D") as Label3D
@onready var sfx_player: AudioStreamPlayer3D = get_node_or_null("SFXPlayer") as AudioStreamPlayer3D

var is_focused: bool = false

var _base_position: Vector3 = Vector3.ZERO
var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0


func _ready() -> void:
	_cache_base_transform()
	_setup_click_target()
	_setup_selection_visuals()


func _process(delta: float) -> void:
	if not enabled:
		return

	_update_hover(delta)

	if allow_confirm_when_focused and is_focused:
		if Input.is_action_just_pressed(confirm_action):
			request_open()


func _cache_base_transform() -> void:
	if visual_root == null:
		visual_root = self

	_base_position = visual_root.position
	_base_scale = visual_root.scale


func _setup_click_target() -> void:
	if click_target == null:
		push_warning("BookInteractable is missing ClickTarget Area3D.")
		return

	click_target.input_ray_pickable = true
	click_target.monitoring = true
	click_target.monitorable = true

	if not click_target.input_event.is_connected(_on_click_target_input_event):
		click_target.input_event.connect(_on_click_target_input_event)

	if not click_target.mouse_entered.is_connected(_on_click_target_mouse_entered):
		click_target.mouse_entered.connect(_on_click_target_mouse_entered)

	if not click_target.mouse_exited.is_connected(_on_click_target_mouse_exited):
		click_target.mouse_exited.connect(_on_click_target_mouse_exited)


func _setup_selection_visuals() -> void:
	if selection_root != null:
		selection_root.visible = false

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = false


func _on_click_target_input_event(
	camera: Node,
	event: InputEvent,
	event_position: Vector3,
	normal: Vector3,
	shape_idx: int
) -> void:
	if not enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			get_viewport().set_input_as_handled()
			_handle_pointer_pressed()

	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch

		if touch_event.pressed:
			get_viewport().set_input_as_handled()
			_handle_pointer_pressed()


func _on_click_target_mouse_entered() -> void:
	if not enabled:
		return

	set_focused(true)


func _on_click_target_mouse_exited() -> void:
	if not enabled:
		return

	set_focused(false)


func _handle_pointer_pressed() -> void:
	set_focused(true)

	if open_on_click:
		request_open()


func set_focused(value: bool) -> void:
	if is_focused == value:
		return

	is_focused = value

	if visual_root != null:
		visual_root.scale = focused_scale if is_focused else _base_scale

	if selection_root != null:
		selection_root.visible = is_focused

	if prompt_label != null:
		prompt_label.text = prompt_text
		prompt_label.visible = is_focused

	if is_focused:
		_play_sfx(focus_sfx)
		focused.emit(self)
	else:
		unfocused.emit(self)


func request_open() -> void:
	if not enabled:
		return

	_play_sfx(open_sfx)
	open_requested.emit(self)


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

	if not is_focused:
		visual_root.position = _base_position
		return

	_time += delta
	var hover_y := sin(_time * hover_speed) * hover_amount
	visual_root.position = _base_position + Vector3(0.0, hover_y, 0.0)


func _play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return

	if sfx_player == null:
		return

	sfx_player.stream = stream
	sfx_player.play()
