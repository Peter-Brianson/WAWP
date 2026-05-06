extends Resource
class_name BookGameEntry

@export var game_id: StringName = &""
@export var display_name: String = "Card Game"
@export_multiline var description: String = ""
@export_multiline var rules_summary: String = ""
@export_range(1, 8, 1) var min_players: int = 2
@export_range(1, 8, 1) var max_players: int = 8
@export var starts_unlocked: bool = true
@export var min_boredom_required: int = 0
@export var min_games_played_required: int = 0
@export var minigame_scene: PackedScene
