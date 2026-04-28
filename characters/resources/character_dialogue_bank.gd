extends Resource
class_name CharacterDialogueBank

@export var lines: Array[CharacterDialogueLine] = []

func get_matching_lines(moment: CharacterDialogueLine.Moment, context_tag: StringName = &"") -> Array[CharacterDialogueLine]:
	var matches: Array[CharacterDialogueLine] = []

	for line in lines:
		if line == null:
			continue
		if line.moment != moment:
			continue
		if context_tag != &"" and line.context_tag != &"" and line.context_tag != context_tag:
			continue
		matches.append(line)

	return matches
