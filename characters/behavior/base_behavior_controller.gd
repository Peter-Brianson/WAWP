extends Node
class_name BaseBehaviorController

var character: BaseCharacter
var character_definition: CharacterDefinition
var behavior_tree: Resource

func set_character(value: BaseCharacter) -> void:
	character = value

func set_character_definition(value: CharacterDefinition) -> void:
	character_definition = value

func set_behavior_tree(value: Resource) -> void:
	behavior_tree = value
