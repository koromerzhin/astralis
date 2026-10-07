class_name Hud
extends Control

const STATUS_BAR_HEIGHT := 88.0
signal log_toggled

const LOG_WIDTH := 470.0
const LOG_HEIGHT := 210.0
const LOG_COLLAPSED_HEIGHT := 36.0
const MAX_LOG_ENTRIES := 40

const PANEL_COLOR := Color(0.04, 0.06, 0.1, 0.9)
const BORDER_COLOR := Color(0.3, 0.55, 0.75, 0.6)
const ACCENT_COLOR := Color(0.4, 0.75, 1.0)
const PLAYER_EVENT_COLOR := Color(1.0, 0.85, 0.38)
const OTHER_EVENT_COLOR := Color(0.6, 0.67, 0.76)
const STATS_COLOR := Color(0.82, 0.87, 0.93)

var simulation_manager: SimulationManager
var player: PlayerData

var _year_label: Label
var _identity_label: Label
var _resources_label: Label
var _log_panel: Panel
var _log_toggle_button: Button
var _log_text: RichTextLabel
var _speed_values: Array[float] = []
var _speed_buttons: Array[Button] = []
var _entries: Array[Dictionary] = []
var _log_collapsed: bool = false


func setup(
	simulation_manager_value: SimulationManager,
	player_value: PlayerData
) -> void:
	simulation_manager = simulation_manager_value
	player = player_value


func is_log_collapsed() -> bool:
	return _log_collapsed


func get_log_height() -> float:
	return LOG_COLLAPSED_HEIGHT if _log_collapsed else LOG_HEIGHT


func get_reserved_bottom_height() -> float:
	return STATUS_BAR_HEIGHT + 12.0 + get_log_height()


func toggle_log() -> void:
	_log_collapsed = not _log_collapsed

	_apply_log_layout()
	log_toggled.emit()


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_status_bar()
	_build_log_panel()

	if simulation_manager != null:
		simulation_manager.year_changed.connect(
			_on_year_changed
		)

		simulation_manager.event_logged.connect(
			_on_event_logged
		)

	refresh()


func _build_status_bar() -> void:
	var bar := Panel.new()

	bar.name = "StatusBar"
	bar.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_WIDE
	)
	bar.offset_top = -STATUS_BAR_HEIGHT
	bar.offset_bottom = 0.0
	bar.add_theme_stylebox_override(
		"panel",
		_make_panel_style()
	)

	add_child(bar)

	var margin := MarginContainer.new()

	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	bar.add_child(margin)

	var row := HBoxContainer.new()

	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	margin.add_child(row)

	_year_label = Label.new()
	_year_label.text = "An 0"
	_year_label.add_theme_font_size_override(
		"font_size",
		24
	)
	_year_label.add_theme_color_override(
		"font_color",
		ACCENT_COLOR
	)

	row.add_child(_year_label)

	var group := ButtonGroup.new()

	for speed in [1.0, 2.0, 4.0]:
		var button := Button.new()

		button.text = "x" + str(int(speed))
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(54, 36)

		button.pressed.connect(
			_on_speed_pressed.bind(speed)
		)

		row.add_child(button)

		_speed_buttons.append(button)
		_speed_values.append(speed)

	var spacer := Control.new()

	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(spacer)

	var stats := VBoxContainer.new()

	stats.add_theme_constant_override("separation", 2)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(stats)

	_identity_label = Label.new()
	_identity_label.text = ""
	_identity_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_identity_label.add_theme_font_size_override(
		"font_size",
		16
	)

	stats.add_child(_identity_label)

	_resources_label = Label.new()
	_resources_label.text = ""
	_resources_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	_resources_label.add_theme_font_size_override(
		"font_size",
		15
	)
	_resources_label.add_theme_color_override(
		"font_color",
		STATS_COLOR
	)

	stats.add_child(_resources_label)


func _build_log_panel() -> void:
	var panel := Panel.new()

	panel.name = "LogPanel"
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_RIGHT
	)
	panel.offset_left = -LOG_WIDTH - 12.0
	panel.offset_right = -12.0
	panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style()
	)

	add_child(panel)

	_log_panel = panel

	_apply_log_layout()

	var margin := MarginContainer.new()

	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.add_child(margin)

	var column := VBoxContainer.new()

	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE

	margin.add_child(column)

	var header := HBoxContainer.new()

	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	column.add_child(header)

	var title := Label.new()

	title.text = "JOURNAL"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override(
		"font_color",
		ACCENT_COLOR
	)

	header.add_child(title)

	_log_toggle_button = Button.new()
	_log_toggle_button.text = "▾"
	_log_toggle_button.focus_mode = Control.FOCUS_NONE
	_log_toggle_button.custom_minimum_size = Vector2(28, 22)
	_log_toggle_button.pressed.connect(toggle_log)

	header.add_child(_log_toggle_button)

	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = false
	_log_text.scroll_following = true
	_log_text.selection_enabled = false
	_log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.add_theme_font_size_override(
		"normal_font_size",
		14
	)
	_log_text.add_theme_color_override(
		"default_color",
		OTHER_EVENT_COLOR
	)

	column.add_child(_log_text)

	_apply_log_layout()


func _apply_log_layout() -> void:
	if _log_panel == null:
		return

	var height: float = (
		LOG_COLLAPSED_HEIGHT
		if _log_collapsed
		else LOG_HEIGHT
	)

	_log_panel.offset_top = -(
		STATUS_BAR_HEIGHT + 12.0 + height
	)
	_log_panel.offset_bottom = -(STATUS_BAR_HEIGHT + 12.0)

	if _log_text != null:
		_log_text.visible = not _log_collapsed

	if _log_toggle_button != null:
		_log_toggle_button.text = "▸" if _log_collapsed else "▾"


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)

	return style


func refresh() -> void:
	if simulation_manager == null:
		return

	_year_label.text = (
		"An " + str(simulation_manager.current_year)
	)

	_update_stats()
	_update_speed_buttons()


func _update_stats() -> void:
	var civilization: CivilizationData = null

	if player != null:
		civilization = simulation_manager.get_civilization(
			player.civilization_id
		)

	if civilization == null:
		_identity_label.text = "Aucune civilisation"
		_resources_label.text = ""
		return

	var system_count: int = (
		simulation_manager.get_controlled_system_count(
			civilization.global_id
		)
	)

	var incomes: float = (
		civilization.colony_income
		+ civilization.trade_income
	)

	_identity_label.text = (
		civilization.name
		+ "   |   Population "
		+ _format_int(
			civilization.get_total_population()
		)
		+ "   |   Colonies "
		+ str(civilization.colonies.size())
		+ "   |   Systèmes "
		+ str(system_count)
	)

	_resources_label.text = (
		"Économie "
		+ _format_float(civilization.economy)
		+ "   |   Technologie "
		+ _format_float(civilization.technology)
		+ "   |   Militaire "
		+ _format_float(civilization.military_power)
		+ "   |   Revenus +"
		+ _format_float(incomes)
		+ "/an"
		+ "   |   Budget "
		+ _format_float(civilization.expansion_budget)
	)


func _update_speed_buttons() -> void:
	if simulation_manager == null:
		return

	var current_speed: float = (
		simulation_manager.years_per_second
	)

	for i in _speed_buttons.size():
		_speed_buttons[i].button_pressed = (
			is_equal_approx(
				_speed_values[i],
				current_speed
			)
		)


func _on_speed_pressed(speed: float) -> void:
	if simulation_manager == null:
		return

	if is_equal_approx(
		simulation_manager.years_per_second,
		speed
	):
		return

	simulation_manager.years_per_second = speed

	_update_speed_buttons()


func _on_year_changed(year: int) -> void:
	_year_label.text = "An " + str(year)

	_update_stats()


func _on_event_logged(
	event_text: String,
	involves_player: bool
) -> void:
	add_event(event_text, involves_player)


func add_event(
	event_text: String,
	involves_player: bool
) -> void:
	_entries.append({
		"text": event_text,
		"player": involves_player,
	})

	while _entries.size() > MAX_LOG_ENTRIES:
		_evict_entry()

	_render_log()


func _evict_entry() -> void:
	for i in _entries.size():
		if not _entries[i]["player"]:
			_entries.remove_at(i)
			return

	_entries.remove_at(0)


func _render_log() -> void:
	_log_text.clear()

	for entry in _entries:
		var is_player: bool = entry["player"]

		_log_text.push_color(
			PLAYER_EVENT_COLOR
			if is_player
			else OTHER_EVENT_COLOR
		)

		if is_player:
			_log_text.add_text("★ ")

		_log_text.add_text(entry["text"])
		_log_text.add_text("\n")

		_log_text.pop()


func _format_int(value: int) -> String:
	var negative: bool = value < 0
	var digits: String = str(absi(value))
	var grouped := ""
	var index: int = digits.length()

	while index > 0:
		var chunk: int = min(3, index)
		var segment: String = digits.substr(
			index - chunk,
			chunk
		)

		if grouped.is_empty():
			grouped = segment
		else:
			grouped = segment + " " + grouped

		index -= chunk

	if negative:
		return "-" + grouped

	return grouped


func _format_float(value: float) -> String:
	var rounded: float = snappedf(value, 0.1)
	var text: String

	if is_equal_approx(rounded, floorf(rounded)):
		text = str(int(rounded))
	else:
		text = str(rounded)

	return text.replace(".", ",")
