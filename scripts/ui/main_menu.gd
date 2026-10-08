extends Control

class_name MainMenu

signal new_game_requested(seed_text: String, civilization_name: String)
signal continue_requested(save_key: String)
signal delete_requested(save_key: String)
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
var seed_box: VBoxContainer
var civ_name_line_edit: LineEdit
var seed_line_edit: LineEdit
var random_seed_button: Button
var start_seed_button: Button
var back_seed_button: Button
var save_box: VBoxContainer
var save_list: VBoxContainer
var back_saves_button: Button
var _overlay: ColorRect
var save_exists := false
var _saves: Array = []

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

	box.custom_minimum_size = Vector2(380, 0)
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
		_on_new_game_pressed
	)
	box.add_child(new_game_button)

	seed_box = VBoxContainer.new()

	seed_box.add_theme_constant_override("separation", 10)
	seed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(seed_box)

	var civ_name_hint := Label.new()

	civ_name_hint.text = "Nom de votre civilisation"
	civ_name_hint.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	seed_box.add_child(civ_name_hint)

	civ_name_line_edit = LineEdit.new()

	civ_name_line_edit.placeholder_text = (
		"Laissez vide pour un nom autogénéré"
	)
	civ_name_line_edit.text_submitted.connect(
		func(_text: String) -> void:
			_on_seed_start()
	)
	seed_box.add_child(civ_name_line_edit)

	var seed_hint_label := Label.new()

	seed_hint_label.text = "Seed de la galaxie"
	seed_hint_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	seed_box.add_child(seed_hint_label)

	seed_line_edit = LineEdit.new()

	seed_line_edit.placeholder_text = (
		"Un nombre, ou un mot de votre choix"
	)
	seed_line_edit.text_submitted.connect(
		func(_text: String) -> void:
			_on_seed_start()
	)
	seed_box.add_child(seed_line_edit)

	var seed_actions := HBoxContainer.new()

	seed_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_box.add_child(seed_actions)

	random_seed_button = _make_button("Aléatoire")
	random_seed_button.pressed.connect(
		_on_seed_random
	)
	seed_actions.add_child(random_seed_button)

	start_seed_button = _make_button("Commencer")
	start_seed_button.pressed.connect(
		_on_seed_start
	)
	seed_actions.add_child(start_seed_button)

	back_seed_button = _make_button("Retour")
	back_seed_button.pressed.connect(
		_on_seed_back
	)
	seed_actions.add_child(back_seed_button)

	seed_box.visible = false

	save_box = VBoxContainer.new()

	save_box.add_theme_constant_override("separation", 10)
	save_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(save_box)

	var save_title_label := Label.new()

	save_title_label.text = "CHOISIR UNE PARTIE"
	save_title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	save_box.add_child(save_title_label)

	var save_scroll := ScrollContainer.new()

	save_scroll.custom_minimum_size = Vector2(380, 220)
	save_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	save_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_box.add_child(save_scroll)

	save_list = VBoxContainer.new()

	save_list.add_theme_constant_override("separation", 8)
	save_list.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	save_scroll.add_child(save_list)

	back_saves_button = _make_button("Retour")
	back_saves_button.pressed.connect(
		_on_saves_back
	)
	save_box.add_child(back_saves_button)

	save_box.visible = false

	continue_button = _make_button("Reprendre la partie")
	continue_button.pressed.connect(
		_on_continue_pressed
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


func _clear_save_list() -> void:
	for child in save_list.get_children():
		save_list.remove_child(child)
		child.queue_free()


func refresh_saves(saves: Array) -> void:
	_saves = saves
	save_exists = not saves.is_empty()
	continue_button.disabled = not save_exists

	_clear_save_list()

	for save_meta in saves:
		var row := HBoxContainer.new()

		row.custom_minimum_size = Vector2(0, 44)
		row.add_theme_constant_override("separation", 8)

		var load_button := _make_button(
			_format_save_label(save_meta)
		)

		load_button.text_overrun_behavior = (
			TextServer.OVERRUN_TRIM_ELLIPSIS
		)
		load_button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		load_button.pressed.connect(
			func() -> void:
				continue_requested.emit(
					save_meta["key"]
				)
		)

		row.add_child(load_button)

		var delete_button := _make_button("Supprimer")

		delete_button.custom_minimum_size = Vector2(110, 44)
		delete_button.pressed.connect(
			func() -> void:
				delete_requested.emit(
					save_meta["key"]
				)
		)

		row.add_child(delete_button)

		save_list.add_child(row)


func _format_save_label(save_meta: Dictionary) -> String:
	var label := str(
		save_meta.get(
			"name",
			"Sans nom"
		)
	)

	label += "  —  seed "
	label += str(
		save_meta.get(
			"seed",
			0
		)
	)

	var saved_at := str(
		save_meta.get(
			"saved_at",
			""
		)
	)

	if saved_at != "":
		if saved_at.length() > 16:
			saved_at = saved_at.substr(0, 16)

		label += "  —  " + saved_at

	return label


func show_boot(
	saves: Array,
	seed_default: String = ""
) -> void:
	_saves = saves

	title_label.text = "ASTRALIS"
	subtitle_label.text = "En quête d'un nouvel essor"

	new_game_button.visible = true
	continue_button.visible = true
	resume_button.visible = false
	save_button.visible = false
	main_menu_button.visible = false
	quit_button.visible = true

	seed_box.visible = false
	seed_line_edit.text = seed_default
	civ_name_line_edit.text = ""

	save_box.visible = false

	refresh_saves(saves)

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

	seed_box.visible = false
	save_box.visible = false

	visible = true


func refresh_save_state(has_save: bool) -> void:
	save_exists = has_save
	continue_button.disabled = not has_save


func _on_new_game_pressed() -> void:
	title_label.text = "NOUVELLE PARTIE"
	subtitle_label.text = "Votre civilisation au cœur de la galaxie"

	new_game_button.visible = false
	continue_button.visible = false
	quit_button.visible = false

	seed_box.visible = true

	civ_name_line_edit.grab_focus()


func _on_seed_back() -> void:
	seed_box.visible = false
	show_boot(_saves, seed_line_edit.text)


func _on_seed_start() -> void:
	new_game_requested.emit(
		seed_line_edit.text,
		civ_name_line_edit.text
	)


func _on_seed_random() -> void:
	var rng := RandomNumberGenerator.new()

	rng.randomize()
	seed_line_edit.text = String.num_int64(
		rng.randi_range(1, 999999999)
	)


func _on_continue_pressed() -> void:
	if not save_exists:
		return

	title_label.text = "REPRENDRE"
	subtitle_label.text = "Choisissez une partie"

	new_game_button.visible = false
	continue_button.visible = false
	quit_button.visible = false

	save_box.visible = true


func _on_saves_back() -> void:
	save_box.visible = false
	show_boot(_saves, seed_line_edit.text)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey:
		if not event.pressed:
			return

		if event.keycode == KEY_ESCAPE:
			if seed_box.visible:
				_on_seed_back()
			elif save_box.visible:
				_on_saves_back()
			elif resume_button.visible:
				resume_requested.emit()