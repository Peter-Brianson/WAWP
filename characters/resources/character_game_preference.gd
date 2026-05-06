extends Resource
class_name CharacterGamePreference

@export var game_id: StringName = &""
@export_range(-5, 5, 1) var score: int = 0
@export_multiline var pick_comment: String = ""
@export_multiline var win_comment: String = ""
@export_multiline var lose_comment: String = ""
