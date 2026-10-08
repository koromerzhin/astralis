extends Panel

signal planet_focused(planet: PlanetData)

const PANEL_COLOR := Color(0.05, 0.1, 0.2, 0.85)
const BORDER_COLOR := Color(0.3, 0.5, 0.8, 0.6)
const ACCENT_COLOR := Color(0.5, 0.8, 1.0, 0.9)

@onready var item_container: VBoxContainer

var system_view: Node2D
var items: Array = []
var ship_planet_id: int = -1

func _init() -> void:
	name = "SystemPlanetList"
	theme = null
	focus_mode = FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Colonne gauche, sous StarInfo (bottom 320) et le bouton de nav
	# (332..372 quand StarInfo est visible).
	position = Vector2(20.0, 384.0)
	size = Vector2(350.0, 300.0)
	custom_minimum_size = Vector2(350.0, 160.0)

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "PLANÈTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	vbox.add_child(scroll)

	item_container = VBoxContainer.new()
	item_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_container.add_theme_constant_override("separation", 2)
	scroll.add_child(item_container)


func setup(view: Node2D) -> void:
	system_view = view
	if system_view != null and not system_view.planet_selected.is_connected(highlight):
		system_view.planet_selected.connect(highlight)


func set_ship_planet_id(planet_id: int) -> void:
	if ship_planet_id == planet_id:
		return

	ship_planet_id = planet_id
	refresh_statuses()


func highlight(planet: PlanetData) -> void:
	for item in items:
		var btn: Button = item.get("button")
		if btn == null:
			continue
		if item.get("planet") == planet:
			btn.modulate = ACCENT_COLOR
		else:
			btn.modulate = Color(1, 1, 1, 1)


func rebuild(planets: Array[PlanetData]) -> void:
	for item in items:
		item["hbox"].queue_free()
	items.clear()

	var list := planets.duplicate()
	list.sort_custom(func(a: PlanetData, b: PlanetData) -> bool:
		return a.global_id < b.global_id
	)

	for planet in list:
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 4)
		item_container.add_child(hbox)

		var ship_tag := Label.new()
		ship_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ship_tag.text = "VAISSEAU"
		ship_tag.custom_minimum_size = Vector2(76, 0)
		ship_tag.visible = false
		ship_tag.add_theme_color_override("font_color", ACCENT_COLOR)
		ship_tag.add_theme_font_size_override("font_size", 11)
		hbox.add_child(ship_tag)

		var btn := Button.new()
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.focus_mode = FOCUS_NONE
		btn.text = "Planète #%d · %s" % [planet.global_id, planet.type]
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
		btn.pressed.connect(func() -> void:
			planet_focused.emit(planet)
			if system_view != null:
				system_view.focus_planet(planet)
		)
		hbox.add_child(btn)

		var status := Label.new()
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status.custom_minimum_size = Vector2(110, 0)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(status)

		items.append({
			"planet": planet,
			"button": btn,
			"status": status,
			"ship_tag": ship_tag,
			"hbox": hbox
		})

	refresh_statuses()


func refresh_statuses() -> void:
	for item in items:
		var planet: PlanetData = item.get("planet")
		var status: Label = item.get("status")
		var ship_tag: Label = item.get("ship_tag")
		if planet == null or status == null:
			continue

		if ship_tag != null:
			ship_tag.visible = (
				ship_planet_id >= 0
				and planet.global_id == ship_planet_id
			)
		var text: String
		var color: Color
		if planet.colony != null:
			text = "COLONIE"
			color = ACCENT_COLOR
		elif planet.type == "gas_giant":
			text = "GÉANTE GAZEUSE —"
			color = Color(0.6, 0.6, 0.6, 0.8)
		elif planet.is_explored and planet.is_studied:
			text = "ÉTUDIÉE"
			color = Color(0.4, 0.9, 1.0, 0.9)
		elif planet.is_explored:
			text = "EXPLORÉE"
			color = Color(0.4, 1.0, 0.6, 0.9)
		else:
			text = "NON EXPLORÉE"
			color = Color(0.8, 0.8, 0.8, 0.7)
		status.text = text
		status.add_theme_color_override("font_color", color)
