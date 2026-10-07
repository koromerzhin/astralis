extends Control

class_name MainMenu

signal new_game_requested
signal continue_requested
signal resume_requested
signal save_requested
signal main_menu_requested
signal quit_requested

var new_game_button: Button
var continue_button: Button
var resume_button: Button
var save_button: Button
var main_menu_button: Button
var quit_button: Button
var title_label: Label
var subtitle_label: Label
var _overlay: ColorRect

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.02, 0.05, 0.96)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var center := CenterContainer.new()

	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()

	box.custom_minimum_size = Vector2(340, 0)
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	title_label = Label.new()
	title_label.text = "ASTRA LIS"
	title_label.add_theme_font_size_override("font_size", 46)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.65, 0.75)
	)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle_label)

	box.add_child(
		_make_spacer()
	)

	new_game_button = _make_button("Nouvelle partie")
	new_game_button.pressed.connect(
		func() -> void:
			new_game_requested.emit()
	)
	box.add_child(new_game_button)

	continue_button = _make_button("Reprendre la partie")
	continue_button.pressed.connect(
		func() -> void:
			continue_requested.emit()
	)
	box.add_child(continue_button)

	resume_button = _make_button("Reprendre")
	resume_button.pressed.connect(
		func() -> void:
			resume_requested.emit()
	)
	box.add_child(resume_button)

	save_button = _make_button("Sauvegarder")
	save_button.pressed.connect(
		func() -> void:
			save_requested.emit()
	)
	box.add_child(save_button)

	main_menu_button = _make_button("Menu principal")
	main_menu_button.pressed.connect(
		func() -> void:
			main_menu_requested.emit()
	)
	box.add_child(main_menu_button)

	quit_button = _make_button("Quitter")
	quit_button.pressed.connect(
		func() -> void:
			quit_requested.emit()
	)
	box.add_child(quit_button)


func _make_button(text: String) -> Button:
	var button := Button.new()

	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 44)
	return button


func _make_spacer() -> Control:
	var spacer := Control.new()

	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func show_boot(has_save: bool) -> void:
	title_label.text = "ASTRALIS"
	subtitle_label.text = "En quête d'un nouvel essor"

	new_game_button.visible = true
	continue_button.visible = true
	resume_button.visible = false
	save_button.visible = false
	main_menu_button.visible = false
	quit_button.visible = true

	refresh_save_state(has_save)

	visible = true


func show_pause() -> void:
	title_label.text = "MENU"
	subtitle_label.text = ""

	new_game_button.visible = false
	continue_button.visible = false
	resume_button.visible = true
	save_button.visible = true
	main_menu_button.visible = true
	quit_button.visible = true

	visible = true


func refresh_save_state(has_save: bool) -> void:
	continue_button.disabled = not has_save


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey:
		if not event.pressed:
			return

		if event.keycode == KEY_ESCAPE:
			if resume_button.visible:
				resume_requested.emit()