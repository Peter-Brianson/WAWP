extends Control

signal slot_chosen(slot_id: String)
signal back_requested

@onready var empty_label: Label = $MarginContainer/VBoxContainer/EmptyLabel
@onready var save_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/SaveList
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)


func on_screen_opened() -> void:
	refresh_list()


func refresh_list() -> void:
	for child in save_list.get_children():
		child.queue_free()

	var saves: Array[Dictionary] = SaveManager.list_saves()
	empty_label.visible = saves.is_empty()

	for save_data in saves:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s | %s | %s" % [
			str(save_data.get("display_name", "Unknown Save")),
			str(save_data.get("chapter", "Unknown Chapter")),
			str(save_data.get("played_at_text", "Unknown Time"))
		]
		button.pressed.connect(_on_slot_pressed.bind(str(save_data.get("slot_id", ""))))
		save_list.add_child(button)

	if save_list.get_child_count() > 0:
		var first := save_list.get_child(0)
		if first is Button:
			first.grab_focus()
	else:
		back_button.grab_focus()


func _on_slot_pressed(slot_id: String) -> void:
	slot_chosen.emit(slot_id)


func _on_back_pressed() -> void:
	back_requested.emit()
