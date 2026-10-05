extends Node2D

signal star_selected(star: Dictionary)

var stars: Array[Dictionary] = []
var selected_star_id := -1
var player: PlayerData

@export var move_speed := 500.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.25
@export var max_zoom := 4.0
@export var star_min_zoom := 0.5
@export var star_max_zoom := 2.0

@export var galaxy_radius := 1200.0
@export var galaxy_arm_count := 4
@export var galaxy_arm_twist := 2.5
@export var galaxy_arm_width := 0.35

@onready var camera: Camera2D = $Camera2D


func set_stars(new_stars: Array[Dictionary]) -> void:
	stars = new_stars
	queue_redraw()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1

	if direction != Vector2.ZERO:
		camera.position += (
			direction.normalized()
			* move_speed
			* delta
		)

	if player != null:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom(1.0 - zoom_speed)

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.0 + zoom_speed)

			elif event.button_index == MOUSE_BUTTON_LEFT:
				_select_star_at_position(
					get_global_mouse_position()
				)

func _select_star_at_position(mouse_position: Vector2) -> void:
	var closest_star_id := -1
	var closest_distance: float = INF

	for star in stars:
		var star_position: Vector2 = star["position"]
		var distance: float = mouse_position.distance_to(star_position)

		if distance < closest_distance:
			closest_distance = distance
			closest_star_id = star["id"]

	var selection_distance: float = 20.0 / camera.zoom.x

	if closest_distance <= selection_distance:
		selected_star_id = closest_star_id
		star_selected.emit(_get_star_by_id(closest_star_id))
		queue_redraw()

func _get_star_by_id(star_id: int) -> Dictionary:
	for star in stars:
		if star["id"] == star_id:
			return star

	return {}


func _zoom(factor: float) -> void:
	var new_zoom := camera.zoom.x * factor
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)

	camera.zoom = Vector2(new_zoom, new_zoom)

	queue_redraw()

func _draw() -> void:
	var zoom: float = camera.zoom.x

	_draw_galaxy(zoom)
	_draw_stars(zoom)

	if player != null:
		_draw_player_system_marker(zoom)
		_draw_travel_route(zoom)
		_draw_player_ship(zoom)

func _draw_galaxy(zoom: float) -> void:
	var visibility := inverse_lerp(
		0.25,
		1.0,
		zoom
	)

	visibility = clamp(visibility, 0.0, 1.0)

	var rings := 40
	var points_per_ring := 80

	for ring in rings:
		var radius := galaxy_radius * float(ring + 1) / float(rings)

		for point in points_per_ring:
			var angle := TAU * float(point) / float(points_per_ring)

			for arm in galaxy_arm_count:
				var arm_angle := (
					TAU * float(arm) / float(galaxy_arm_count)
				)

				var spiral_angle := (
					radius / galaxy_radius
					* galaxy_arm_twist
					* TAU
				)

				var angle_offset := (
					arm_angle
					+ spiral_angle
				)

				var final_angle := angle_offset + angle

				var position := Vector2(
					cos(final_angle) * radius,
					sin(final_angle) * radius
				)

				var distance_from_arm: float = abs(
					sin(angle * 3.0)
				)

				var alpha: float = (
					0.015
					+ distance_from_arm * 0.015
				)

				alpha *= visibility

				draw_circle(
					position,
					1.5,
					Color(0.6, 0.7, 1.0, alpha)
				)

func _draw_stars(zoom: float) -> void:
	var visibility := inverse_lerp(
		0.5,
		2.0,
		zoom
	)

	visibility = clamp(visibility, 0.0, 1.0)

	for star in stars:
		var position: Vector2 = star["position"]
		var star_type: String = star["type"]

		var color := _get_star_color(star_type)
		var radius := _get_star_radius(star_type)

		color.a = visibility

		draw_circle(
			position,
			radius,
			color
		)

		if star["id"] == selected_star_id:
			draw_circle(
				position,
				radius + 6.0,
				Color.WHITE,
				false,
				2.0
			)


func _get_star_color(star_type: String) -> Color:
	match star_type:
		"red_dwarf":
			return Color(1.0, 0.35, 0.2)

		"yellow":
			return Color(1.0, 0.9, 0.4)

		"orange":
			return Color(1.0, 0.55, 0.2)

		"blue":
			return Color(0.3, 0.6, 1.0)

		"white":
			return Color(0.95, 0.95, 1.0)

		_:
			return Color.WHITE


func _get_star_radius(star_type: String) -> float:
	match star_type:
		"red_dwarf":
			return 2.0

		"yellow":
			return 3.0

		"orange":
			return 2.5

		"blue":
			return 3.5

		"white":
			return 3.0

		_:
			return 2.0

func set_player(player_data: PlayerData) -> void:
	player = player_data
	queue_redraw()

func _draw_player_ship(zoom: float) -> void:
	var position: Vector2 = player.position

	var ship_scale: float = clamp(
		1.0 / zoom,
		0.8,
		3.0
	)

	var direction := Vector2.RIGHT

	if player.traveling:
		direction = (
			player.travel_target_position
			- player.position
		).normalized()

		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT

	var perpendicular := Vector2(
		-direction.y,
		direction.x
	)

	var nose := position + direction * 10.0 * ship_scale

	var rear_left := (
		position
		- direction * 7.0 * ship_scale
		+ perpendicular * 5.0 * ship_scale
	)

	var rear_right := (
		position
		- direction * 7.0 * ship_scale
		- perpendicular * 5.0 * ship_scale
	)

	var ship_points := PackedVector2Array([
		nose,
		rear_left,
		rear_right
	])

	draw_colored_polygon(
		ship_points,
		Color(0.8, 0.95, 1.0)
	)

	draw_polyline(
		PackedVector2Array([
			nose,
			rear_left,
			rear_right,
			nose
		]),
		Color.WHITE,
		1.5 * ship_scale
	)

	if player.traveling:
		var trail_start := (
			position
			- direction * 8.0 * ship_scale
		)

		var trail_end := (
			position
			- direction * 22.0 * ship_scale
		)

		draw_line(
			trail_start,
			trail_end,
			Color(0.4, 0.8, 1.0, 0.7),
			2.0 * ship_scale
		)

func _draw_player_system_marker(zoom: float) -> void:
	if player.current_system_id < 0:
		return

	var player_position: Vector2 = (
		player.current_system_position
	)

	var pulse := (
		sin(Time.get_ticks_msec() * 0.004) + 1.0
	) * 0.5

	var radius := (
		10.0 + pulse * 3.0
	) / sqrt(zoom)

	radius = clamp(
		radius,
		5.0,
		20.0
	)

	draw_circle(
		player_position,
		radius,
		Color(0.3, 0.8, 1.0, 0.18),
		false,
		2.0 / sqrt(zoom)
	)

	draw_circle(
		player_position,
		radius * 0.55,
		Color(0.3, 0.8, 1.0, 0.35),
		false,
		1.0 / sqrt(zoom)
	)
func _draw_travel_route(zoom: float) -> void:
	if not player.traveling:
		return

	var start_position: Vector2 = (
		player.travel_start_position
	)

	var target_position: Vector2 = (
		player.travel_target_position
	)

	var route_width: float = clamp(
		2.0 / sqrt(zoom),
		0.8,
		3.0
	)

	draw_dashed_line(
		start_position,
		target_position,
		Color(0.4, 0.8, 1.0, 0.45),
		route_width,
		8.0 / sqrt(zoom)
	)

	draw_circle(
		target_position,
		8.0 / sqrt(zoom),
		Color(0.4, 0.8, 1.0, 0.5),
		false,
		route_width
	)
