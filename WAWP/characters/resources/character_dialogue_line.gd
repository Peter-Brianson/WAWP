extends Resource
class_name CharacterDialogueLine

enum Moment {
	INTRO,
	TABLE_IDLE,
	GAME_PICK,
	GAME_START,
	WIN,
	LOSE,
	DRAW,
	BORED,
	INVENTION
}

@export var moment: Moment = Moment.TABLE_IDLE
@export var context_tag: StringName = &""
@export_multiline var text: String = ""
@export var animation: StringName = &"talk"
@export_range(0.1, 100.0, 0.1) var weight: float = 1.0
@export_range(0.25, 3.0, 0.05) var voice_pitch: float = 1.0
@export var once_only: bool = false
