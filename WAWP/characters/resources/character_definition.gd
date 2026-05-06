@tool
extends Resource
class_name CharacterDefinition

@export_group("Identity")
@export var character_id: StringName = &""
@export var display_name: String = ""
@export var species: String = ""

@export_group("Visuals")
@export var sprite_frames: SpriteFrames

@export_subgroup("Core Animations")
@export var idle_animation: StringName = &"idle"
@export var additional_idle_animation: StringName = &"idle_2"
@export var talk_animation: StringName = &"talk"
@export var emote_animation: StringName = &"emote"

@export_subgroup("Game / Reaction Animations")
@export var win_animation: StringName = &"win"
@export var lose_animation: StringName = &"lose"
@export var draw_animation: StringName = &"draw"
@export var hit_animation: StringName = &"hit"

@export_subgroup("Transform")
@export var sprite_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var sprite_scale: Vector3 = Vector3.ONE
@export_range(0.001, 0.25, 0.001) var pixel_size: float = 0.01

@export_group("Audio")
@export var voice_bloop: AudioStream
@export_range(0.25, 3.0, 0.05) var voice_pitch: float = 1.0

@export_group("Dialogue")
@export var dialogue_bank: CharacterDialogueBank

@export_group("Behavior")
@export var behavior_controller_scene: PackedScene
@export var behavior_tree: Resource

@export_group("Card Game Preferences")
@export var game_preferences: Array[CharacterGamePreference] = []
