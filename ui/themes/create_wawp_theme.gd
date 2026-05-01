@tool
extends EditorScript


func _run() -> void:
	var theme := Theme.new()

	_create_label_variation(theme, "GameTitleLabel", 28, 6)
	_create_label_variation(theme, "GameStatusLabel", 18, 4)

	_create_panel_variation(theme, "GamePanel")

	_create_button_variation(theme, "GameButton")
	_create_card_button_variation(theme, "CardButton", Color(0.93, 0.84, 0.62, 1.0), Color(0.20, 0.12, 0.06, 1.0), 2)
	_create_card_button_variation(theme, "HoveredCardButton", Color(1.0, 0.92, 0.62, 1.0), Color(0.18, 0.45, 0.16, 1.0), 4)
	_create_card_button_variation(theme, "SelectedCardButton", Color(1.0, 0.82, 0.42, 1.0), Color(0.08, 0.32, 0.08, 1.0), 5)

	ResourceSaver.save(theme, "res://ui/themes/wawp_ui_theme.tres")
	print("Saved WAWP UI theme.")


func _create_label_variation(theme: Theme, variation_name: String, font_size: int, outline_size: int) -> void:
	theme.set_type_variation(variation_name, "Label")
	theme.set_color("font_color", variation_name, Color(1.0, 1.0, 0.92, 1.0))
	theme.set_color("font_outline_color", variation_name, Color(0.02, 0.02, 0.015, 1.0))
	theme.set_constant("outline_size", variation_name, outline_size)
	theme.set_font_size("font_size", variation_name, font_size)


func _create_panel_variation(theme: Theme, variation_name: String) -> void:
	theme.set_type_variation(variation_name, "PanelContainer")

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.20, 0.13, 0.075, 0.88)
	panel_style.border_color = Color(0.035, 0.025, 0.015, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 12

	theme.set_stylebox("panel", variation_name, panel_style)


func _create_button_variation(theme: Theme, variation_name: String) -> void:
	theme.set_type_variation(variation_name, "Button")

	theme.set_color("font_color", variation_name, Color(1.0, 1.0, 0.92, 1.0))
	theme.set_color("font_hover_color", variation_name, Color(1.0, 0.96, 0.65, 1.0))
	theme.set_color("font_pressed_color", variation_name, Color(1.0, 0.84, 0.35, 1.0))
	theme.set_color("font_disabled_color", variation_name, Color(0.55, 0.55, 0.50, 1.0))
	theme.set_color("font_outline_color", variation_name, Color(0.0, 0.0, 0.0, 1.0))
	theme.set_constant("outline_size", variation_name, 3)
	theme.set_font_size("font_size", variation_name, 17)

	theme.set_stylebox("normal", variation_name, _make_button_style(Color(0.18, 0.30, 0.20, 0.95), Color(0.04, 0.06, 0.04, 1.0), 2))
	theme.set_stylebox("hover", variation_name, _make_button_style(Color(0.28, 0.42, 0.24, 0.98), Color(0.78, 0.66, 0.22, 1.0), 3))
	theme.set_stylebox("pressed", variation_name, _make_button_style(Color(0.12, 0.22, 0.14, 1.0), Color(0.95, 0.74, 0.22, 1.0), 3))
	theme.set_stylebox("disabled", variation_name, _make_button_style(Color(0.12, 0.12, 0.11, 0.75), Color(0.03, 0.03, 0.03, 1.0), 2))
	theme.set_stylebox("focus", variation_name, _make_button_style(Color(0.28, 0.42, 0.24, 0.98), Color(1.0, 0.86, 0.30, 1.0), 4))


func _create_card_button_variation(
	theme: Theme,
	variation_name: String,
	bg_color: Color,
	border_color: Color,
	border_width: int
) -> void:
	theme.set_type_variation(variation_name, "Button")

	theme.set_color("font_color", variation_name, Color(0.12, 0.07, 0.035, 1.0))
	theme.set_color("font_hover_color", variation_name, Color(0.08, 0.05, 0.025, 1.0))
	theme.set_color("font_pressed_color", variation_name, Color(0.08, 0.05, 0.025, 1.0))
	theme.set_color("font_outline_color", variation_name, Color(1.0, 0.95, 0.78, 0.85))
	theme.set_constant("outline_size", variation_name, 1)
	theme.set_font_size("font_size", variation_name, 22)

	var style := _make_button_style(bg_color, border_color, border_width)

	theme.set_stylebox("normal", variation_name, style)
	theme.set_stylebox("hover", variation_name, style)
	theme.set_stylebox("pressed", variation_name, style)
	theme.set_stylebox("focus", variation_name, style)
	theme.set_stylebox("disabled", variation_name, style)


func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	return style
