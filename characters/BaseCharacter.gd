@tool
extends Node3D
class_name BaseCharacter

signal dialogue_requested(character: BaseCharacter, line: CharacterDialogueLine)

@export var definition: CharacterDefinition:
	set(value):
		definition = value
		if is_inside_tree():
			_apply_definition()

@onready var visual_root: Node3D = $VisualRoot
@onready var sprite: AnimatedSprite3D = $VisualRoot/AnimatedSprite3D
@onready var dialogue_anchor: Marker3D = $DialogueAnchor
@onready var behavior_holder: Node = $BehaviorHolder
@onready var voice_player: AudioStreamPlayer3D = $VoicePlayer3D

var _behavior_instance: Node = null
var _return_to_idle_after_finish: bool = false
var _use_additional_idle_on_return: bool = false

func _ready() -> void:
	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)

	_apply_definition()

func _apply_definition() -> void:
	if definition == null:
		return
	if sprite == null:
		return

	if definition.display_name != "":
		name = definition.display_name
	elif String(definition.character_id) != "":
		name = String(definition.character_id)

	sprite.sprite_frames = definition.sprite_frames
	sprite.position = definition.sprite_offset
	sprite.pixel_size = definition.pixel_size
	visual_root.scale = definition.sprite_scale

	if voice_player != null:
		voice_player.stream = definition.voice_bloop
		voice_player.pitch_scale = definition.voice_pitch

	play_idle()
	_rebuild_behavior()

func _rebuild_behavior() -> void:
	if behavior_holder == null:
		return

	if _behavior_instance != null and is_instance_valid(_behavior_instance):
		_behavior_instance.queue_free()
		_behavior_instance = null

	if definition == null or definition.behavior_controller_scene == null:
		return

	if Engine.is_editor_hint():
		return

	_behavior_instance = definition.behavior_controller_scene.instantiate()
	behavior_holder.add_child(_behavior_instance)

	if _behavior_instance.has_method("set_character"):
		_behavior_instance.call("set_character", self)

	if _behavior_instance.has_method("set_character_definition"):
		_behavior_instance.call("set_character_definition", definition)

	if definition.behavior_tree != null and _behavior_instance.has_method("set_behavior_tree"):
		_behavior_instance.call("set_behavior_tree", definition.behavior_tree)

func has_animation(animation_name: StringName) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	if String(animation_name) == "":
		return false
	return sprite.sprite_frames.has_animation(String(animation_name))

func _animation_loops(animation_name: StringName) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	if String(animation_name) == "":
		return false
	if not has_animation(animation_name):
		return false
	return sprite.sprite_frames.get_animation_loop(String(animation_name))

func play_animation(animation_name: StringName, fallback: StringName = &"idle") -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var chosen: String = String(animation_name)
	var fallback_name: String = String(fallback)

	if chosen != "" and sprite.sprite_frames.has_animation(chosen):
		sprite.play(chosen)
		return

	if fallback_name != "" and sprite.sprite_frames.has_animation(fallback_name):
		sprite.play(fallback_name)
		return

	sprite.stop()

func play_idle(use_additional_if_available: bool = false) -> void:
	if definition == null:
		return

	_return_to_idle_after_finish = false
	_use_additional_idle_on_return = false

	if use_additional_if_available and has_animation(definition.additional_idle_animation):
		play_animation(definition.additional_idle_animation, definition.idle_animation)
		return

	play_animation(definition.idle_animation)

func play_random_idle() -> void:
	if definition == null:
		return

	_return_to_idle_after_finish = false
	_use_additional_idle_on_return = false

	var choices: Array[StringName] = []

	if has_animation(definition.idle_animation):
		choices.append(definition.idle_animation)

	if has_animation(definition.additional_idle_animation):
		choices.append(definition.additional_idle_animation)

	if choices.is_empty():
		sprite.stop()
		return

	var picked: StringName = choices[randi() % choices.size()]
	play_animation(picked, definition.idle_animation)

func play_talk() -> void:
	if definition == null:
		return

	_return_to_idle_after_finish = false
	_use_additional_idle_on_return = false
	play_animation(definition.talk_animation, definition.idle_animation)

func play_emote() -> void:
	if definition == null:
		return
	_play_one_shot_then_idle(definition.emote_animation)

func play_win() -> void:
	if definition == null:
		return
	_play_one_shot_then_idle(definition.win_animation)

func play_lose() -> void:
	if definition == null:
		return
	_play_one_shot_then_idle(definition.lose_animation)

func play_draw() -> void:
	if definition == null:
		return
	_play_one_shot_then_idle(definition.draw_animation)

func play_hit() -> void:
	if definition == null:
		return
	_play_one_shot_then_idle(definition.hit_animation)

func _play_one_shot_then_idle(animation_name: StringName) -> void:
	if definition == null:
		return

	if not has_animation(animation_name):
		play_random_idle()
		return

	play_animation(animation_name, definition.idle_animation)

	if _animation_loops(animation_name):
		_return_to_idle_after_finish = false
		_use_additional_idle_on_return = false
	else:
		_return_to_idle_after_finish = true
		_use_additional_idle_on_return = randf() < 0.5 and has_animation(definition.additional_idle_animation)

func _on_sprite_animation_finished() -> void:
	if not _return_to_idle_after_finish:
		return

	_return_to_idle_after_finish = false

	if _use_additional_idle_on_return and has_animation(definition.additional_idle_animation):
		_use_additional_idle_on_return = false
		play_animation(definition.additional_idle_animation, definition.idle_animation)
		return

	_use_additional_idle_on_return = false
	play_animation(definition.idle_animation)

func speak(moment: CharacterDialogueLine.Moment, context_tag: StringName = &"") -> CharacterDialogueLine:
	if definition == null or definition.dialogue_bank == null:
		return null

	var choices: Array[CharacterDialogueLine] = definition.dialogue_bank.get_matching_lines(moment, context_tag)
	if choices.is_empty():
		return null

	var chosen: CharacterDialogueLine = _pick_weighted_line(choices)
	if chosen == null:
		return null

	_return_to_idle_after_finish = false
	_use_additional_idle_on_return = false

	if chosen.animation != &"":
		play_animation(chosen.animation, definition.talk_animation)
	else:
		play_animation(definition.talk_animation, definition.idle_animation)

	if voice_player != null and voice_player.stream != null:
		voice_player.pitch_scale = definition.voice_pitch * chosen.voice_pitch
		voice_player.play()

	dialogue_requested.emit(self, chosen)
	return chosen

func get_preference_score(game_id: StringName) -> int:
	if definition == null:
		return 0

	for pref in definition.game_preferences:
		if pref != null and pref.game_id == game_id:
			return pref.score

	return 0

func likes_game(game_id: StringName) -> bool:
	return get_preference_score(game_id) > 0

func dislikes_game(game_id: StringName) -> bool:
	return get_preference_score(game_id) < 0

func get_game_preference(game_id: StringName) -> CharacterGamePreference:
	if definition == null:
		return null

	for pref in definition.game_preferences:
		if pref != null and pref.game_id == game_id:
			return pref

	return null

func _pick_weighted_line(lines: Array[CharacterDialogueLine]) -> CharacterDialogueLine:
	var total_weight: float = 0.0

	for line in lines:
		if line != null:
			total_weight += max(line.weight, 0.001)

	if total_weight <= 0.0:
		return lines[0] if not lines.is_empty() else null

	var roll: float = randf() * total_weight
	var running: float = 0.0

	for line in lines:
		if line == null:
			continue
		running += max(line.weight, 0.001)
		if roll <= running:
			return line

	return lines[-1]
