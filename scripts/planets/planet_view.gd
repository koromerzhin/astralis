extends Node2D


var planet: PlanetData
var simulation_manager: SimulationManager
@export var move_speed := 300.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.5
@export var max_zoom := 4.0

@onready var camera: Camera2D = $Camera2D

func set_planet(new_planet: PlanetData) -> void:
	planet = new_planet

	var rng := RandomNumberGenerator.new()
	rng.seed = planet.seed

	planet.set_meta(
		"rotation_angle",
		rng.randf_range(
			0.0,
			TAU
		)
	)

	planet.set_meta(
		"rotation_speed",
		rng.randf_range(
			0.08,
			0.25
		)
	)

	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE

	queue_redraw()

func _draw() -> void:
	if planet == null:
		return

	var radius: float = planet.size * 80.0

	var planet_color := _get_planet_color(
		planet.type
	)

	# Corps de la planète.
	draw_circle(
		Vector2.ZERO,
		radius,
		planet_color
	)

	var rotation_angle: float = (
		planet.get_meta(
			"rotation_angle",
			0.0
		)
	)

	# Surface spécifique au type de planète.
	match planet.type:
		"rocky":
			_draw_rocky_surface(
				radius,
				rotation_angle
			)

		"desert":
			_draw_desert_surface(
				radius,
				rotation_angle
			)

		"ocean":
			_draw_ocean_surface(
				radius,
				rotation_angle
			)

		"ice":
			_draw_ice_surface(
				radius,
				rotation_angle
			)

		"gas_giant":
			_draw_gas_giant_surface(
				radius,
				rotation_angle
			)

	# Méridiens uniquement sur les planètes solides.
	if planet.type != "gas_giant":
		_draw_surface_meridians(
			radius,
			rotation_angle,
			planet_color
		)

	# Atmosphère.
	_draw_atmosphere(
		radius,
		planet.type
	)

	# Éclairage et pénombre.
	_draw_planet_lighting(
		radius,
		rotation_angle
	)

func _get_planet_color(planet_type: String) -> Color:
	match planet_type:
		"rocky":
			return Color(0.55, 0.45, 0.35)

		"desert":
			return Color(0.85, 0.65, 0.3)

		"ocean":
			return Color(0.2, 0.5, 0.9)

		"ice":
			return Color(0.7, 0.85, 1.0)

		"gas_giant":
			return Color(0.8, 0.55, 0.35)

		_:
			return Color.WHITE

func _process(delta: float) -> void:
	if not visible:
		return

	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if direction != Vector2.ZERO:
		camera.position += (
			direction.normalized()
			* move_speed
			/ camera.zoom.x
			* delta
		)

	if planet != null:
		var animated: bool = (
			simulation_manager == null
			or simulation_manager.simulation_running
		)

		if animated:
			var rotation_angle: float = (
				planet.get_meta(
					"rotation_angle",
					0.0
				)
			)

			var rotation_speed: float = (
				planet.get_meta(
					"rotation_speed",
					0.15
				)
			)

			rotation_angle += (
				rotation_speed * delta
			)

			planet.set_meta(
				"rotation_angle",
				rotation_angle
			)

	queue_redraw()

func _zoom(factor: float) -> void:
	var new_zoom: float = camera.zoom.x * factor

	new_zoom = clamp(
		new_zoom,
		min_zoom,
		max_zoom
	)

	camera.zoom = Vector2(
		new_zoom,
		new_zoom
	)

	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		if not event.pressed:
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.0 - zoom_speed)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 + zoom_speed)
			get_viewport().set_input_as_handled()
			return

func _draw_surface_meridians(
	radius: float,
	rotation_angle: float,
	planet_color: Color
) -> void:
	var meridian_count := 8
	var segments := 24

	var surface_color := Color(
		planet_color.r * 0.65,
		planet_color.g * 0.65,
		planet_color.b * 0.65,
		0.28
	)

	for meridian_index in meridian_count:
		var meridian_angle: float = (
			TAU
			* float(meridian_index)
			/ float(meridian_count)
			+ rotation_angle
		)

		var points := PackedVector2Array()

		for segment in segments + 1:
			var latitude: float = (
				-PI * 0.5
				+ PI
				* float(segment)
				/ float(segments)
			)

			var y: float = sin(latitude) * radius

			var horizontal_radius: float = (
				cos(latitude) * radius
			)

			var x: float = (
				cos(meridian_angle)
				* horizontal_radius
			)

			points.append(
				Vector2(x, y)
			)

		if points.size() >= 2:
			draw_polyline(
				points,
				surface_color,
				max(radius * 0.018, 1.0),
				true
			)

func _draw_rocky_surface(
	radius: float,
	rotation_angle: float
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet.seed

	var crater_count := 12

	for i in crater_count:
		var angle := rng.randf_range(
			0.0,
			TAU
		) + rotation_angle

		var distance := rng.randf_range(
			0.15,
			0.75
		) * radius

		var crater_size := rng.randf_range(
			0.02,
			0.08
		) * radius

		var position := Vector2(
			cos(angle) * distance,
			sin(angle) * distance
		)

		draw_circle(
			position,
			crater_size,
			Color(0.25, 0.22, 0.18, 0.35)
		)

		draw_arc(
			position,
			crater_size,
			0.0,
			TAU,
			16,
			Color(0.9, 0.85, 0.75, 0.18),
			max(radius * 0.01, 1.0)
		)
		
func _draw_desert_surface(
	radius: float,
	rotation_angle: float
) -> void:
	var band_count := 10

	for i in band_count:
		var y: float = (
			-0.75
			+ float(i)
			/ float(band_count - 1)
			* 1.5
		) * radius

		var horizontal_radius: float = sqrt(
			max(
				radius * radius
				- y * y,
				0.0
			)
		)

		var offset := sin(
			rotation_angle
			+ float(i) * 0.7
		) * radius * 0.04

		var start := Vector2(
			-horizontal_radius + offset,
			y
		)

		var end := Vector2(
			horizontal_radius + offset,
			y
		)

		draw_line(
			start,
			end,
			Color(0.95, 0.75, 0.4, 0.18),
			max(radius * 0.025, 1.0)
		)

func _draw_ocean_surface(
	radius: float,
	rotation_angle: float
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet.seed

	var continent_count := 5

	for i in continent_count:
		var angle := (
			rng.randf_range(
				0.0,
				TAU
			)
			+ rotation_angle
		)

		var distance := rng.randf_range(
			0.15,
			0.65
		) * radius

		var continent_radius := rng.randf_range(
			0.12,
			0.28
		) * radius

		var center := Vector2(
			cos(angle) * distance,
			sin(angle) * distance
		)

		_draw_irregular_landmass(
			center,
			continent_radius,
			rng
		)

func _draw_irregular_landmass(
	center: Vector2,
	radius: float,
	rng: RandomNumberGenerator
) -> void:
	var points := PackedVector2Array()

	var point_count := 12

	for i in point_count:
		var angle := (
			TAU
			* float(i)
			/ float(point_count)
		)

		var distance := radius * rng.randf_range(
			0.65,
			1.15
		)

		points.append(
			center
			+ Vector2(
				cos(angle) * distance,
				sin(angle) * distance
			)
		)

	draw_colored_polygon(
		points,
		Color(0.35, 0.55, 0.25, 0.85)
	)

func _draw_ice_surface(
	radius: float,
	rotation_angle: float
) -> void:
	var cap_radius := radius * 0.35

	var north_pole := Vector2(
		0.0,
		-radius * 0.65
	)

	var south_pole := Vector2(
		0.0,
		radius * 0.65
	)

	draw_circle(
		north_pole,
		cap_radius,
		Color(0.9, 0.97, 1.0, 0.8)
	)

	draw_circle(
		south_pole,
		cap_radius,
		Color(0.9, 0.97, 1.0, 0.8)
	)

	var ice_line_offset := sin(
		rotation_angle
	) * radius * 0.08

	draw_line(
		Vector2(
			-radius * 0.7 + ice_line_offset,
			-radius * 0.35
		),
		Vector2(
			radius * 0.7 + ice_line_offset,
			-radius * 0.35
		),
		Color(0.85, 0.95, 1.0, 0.45),
		max(radius * 0.04, 1.0)
	)

func _draw_gas_giant_surface(
	radius: float,
	rotation_angle: float
) -> void:
	var band_count := 14

	for i in band_count:
		var normalized_y: float = (
			float(i)
			/ float(band_count - 1)
			* 2.0
			- 1.0
		)

		var y: float = normalized_y * radius * 0.85

		var horizontal_radius: float = sqrt(
			max(
				radius * radius
				- y * y,
				0.0
			)
		)

		var wave := sin(
			rotation_angle * 2.0
			+ normalized_y * 8.0
		) * radius * 0.04

		var start := Vector2(
			-horizontal_radius,
			y + wave
		)

		var end := Vector2(
			horizontal_radius,
			y + wave
		)

		var alpha := 0.12

		if i % 2 == 0:
			alpha = 0.22

		draw_line(
			start,
			end,
			Color(
				0.45,
				0.25,
				0.12,
				alpha
			),
			max(radius * 0.06, 1.0)
		)

func _draw_atmosphere(
	radius: float,
	planet_type: String
) -> void:
	var atmosphere_color := Color(
		0.45,
		0.7,
		1.0,
		0.0
	)

	var atmosphere_strength := 0.0

	match planet_type:
		"ocean":
			atmosphere_color = Color(
				0.25,
				0.65,
				1.0,
				1.0
			)

			atmosphere_strength = 0.28

		"ice":
			atmosphere_color = Color(
				0.7,
				0.9,
				1.0,
				1.0
			)

			atmosphere_strength = 0.22

		"rocky":
			atmosphere_color = Color(
				0.65,
				0.75,
				0.9,
				1.0
			)

			atmosphere_strength = 0.12

		"desert":
			atmosphere_color = Color(
				1.0,
				0.65,
				0.3,
				1.0
			)

			atmosphere_strength = 0.08

		"gas_giant":
			atmosphere_color = Color(
				1.0,
				0.65,
				0.35,
				1.0
			)

			atmosphere_strength = 0.18

	if atmosphere_strength <= 0.0:
		return

	for i in 3:
		var layer_radius := (
			radius
			+ float(i + 1) * radius * 0.025
		)

		var alpha := (
			atmosphere_strength
			* (1.0 - float(i) * 0.3)
		)

		draw_arc(
			Vector2.ZERO,
			layer_radius,
			0.0,
			TAU,
			64,
			Color(
				atmosphere_color.r,
				atmosphere_color.g,
				atmosphere_color.b,
				alpha
			),
			max(
				radius * 0.018,
				1.0
			),
			true
		)

func _draw_planet_lighting(
	radius: float,
	rotation_angle: float
) -> void:
	var light_direction := Vector2(
		cos(rotation_angle),
		sin(rotation_angle)
	).normalized()

	var shadow_direction := -light_direction

	# Décalage de la zone sombre.
	var shadow_center := (
		shadow_direction
		* radius
		* 0.55
	)

	# Plusieurs couches donnent une transition
	# plus douce entre lumière et pénombre.
	var shadow_layers := 12

	for i in shadow_layers:
		var t := float(i) / float(shadow_layers - 1)

		var layer_radius := radius * (
			0.35
			+ t * 0.85
		)

		var alpha := 0.035 + t * 0.045

		var position := shadow_center * (
			0.25 + t * 0.75
		)

		draw_circle(
			position,
			layer_radius,
			Color(
				0.02,
				0.03,
				0.06,
				alpha
			)
		)

	# Ombre finale très légère.
	draw_circle(
		shadow_center,
		radius * 0.78,
		Color(
			0.01,
			0.015,
			0.03,
			0.10
		)
	)
