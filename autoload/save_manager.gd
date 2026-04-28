extends Node

const SAVE_DIR := "user://saves"
const META_FILE := "meta.cfg"

var current_slot_id: String = ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func has_any_save() -> bool:
	return not list_saves().is_empty()


func list_saves() -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return results

	for folder_name in dir.get_directories():
		var meta_path := "%s/%s/%s" % [SAVE_DIR, folder_name, META_FILE]
		var cfg := ConfigFile.new()

		if cfg.load(meta_path) != OK:
			continue

		results.append({
			"slot_id": folder_name,
			"display_name": str(cfg.get_value("meta", "display_name", folder_name)),
			"chapter": str(cfg.get_value("meta", "chapter", "Prologue")),
			"played_at_text": str(cfg.get_value("meta", "played_at_text", "Unknown"))
		})

	return results


func start_new_game(display_name: String = "") -> String:
	var stamp := str(int(Time.get_unix_time_from_system()))
	var slot_id := "slot_%s" % stamp
	var slot_path := "%s/%s" % [SAVE_DIR, slot_id]

	DirAccess.make_dir_recursive_absolute(slot_path)

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "display_name", display_name if display_name != "" else "Save %s" % stamp)
	cfg.set_value("meta", "chapter", "Prologue")
	cfg.set_value("meta", "played_at_text", Time.get_datetime_string_from_system())

	cfg.save("%s/%s" % [slot_path, META_FILE])

	current_slot_id = slot_id
	return slot_id


func continue_from_slot(slot_id: String) -> void:
	current_slot_id = slot_id
