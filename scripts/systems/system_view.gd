extends Node2D

signal planet_selected(planet: PlanetData)

var system: Dictionary = {}
var planets: Array[PlanetData] = []
@export var move_speed := 300.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.4
@export var max_zoom := 3.0

@onready var camera: Camera2D = $Camera2D


func set_system(new_system: Dictionary) -> void:
	system = new_system
	planets = system["planets"]

	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE

	_initialize_planets()

	queue_redraw()

func _initialize_planets() -> void:
	for planet in planets:
		var rng := RandomNumberGenerator.new()
		rng.seed = planet.seed

		planet.set_meta(
			"angle",
			rng.randf_range(0.0, TAU)
		)

		planet.set_meta(
			"orbit_speed",
			80.0 / max(planet.orbit_distance, 50.0)
		)

		_initialize_moons(planet)


func _initialize_moons(planet: PlanetData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet.seed

	var moons: Array[Dictionary] = []

	for i in planet.moon_count:
		var moon_seed: int = rng.randi()

		var distance: float = 18.0 + planet.size * 8.0
		distance += float(i) * 12.0
		distance += rng.randf_range(-3.0, 3.0)

		var size: float = rng.randf_range(0.15, 0.35)
		var orbit_speed: float = rng.randf_range(1.0, 2.5)
		var angle: float = rng.randf_range(0.0, TAU)

		var moon: Dictionary = {
			"id": i,
			"seed": moon_seed,
			"distance": distance,
			"size": size,
			"angle": angle,
			"orbit_speed": orbit_speed
		}

		moons.append(moon)

	planet.set_meta("moons", moons)


func _process(delta: float) -> void:
	if not visible:
		return

	# Déplacement de la caméra.
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

	# Animation des planètes et des lunes.
	for planet in planets:
		var angle: float = planet.get_meta("angle")
		var orbit_speed: float = planet.get_meta("orbit_speed")

		angle += orbit_speed * delta

		planet.set_meta(
			"angle",
			angle
		)

		var moons: Array[Dictionary] = (
			planet.get_meta("moons")
		)

		for moon in moons:
			var moon_angle: float = moon["angle"]
			var moon_orbit_speed: float = moon["orbit_speed"]

			moon_angle += (
				moon_orbit_speed
				* delta
			)

			moon["angle"] = moon_angle

	queue_redraw()

func _draw() -> void:
	# Étoile centrale
	draw_circle(
		Vector2.ZERO,
		25.0,
		Color(1.0, 0.8, 0.3)
	)

	for planet in planets:
		var orbit_distance: float = planet.orbit_distance
		var angle: float = planet.get_meta("angle")

		# Orbite de la planète
		draw_arc(
			Vector2.ZERO,
			orbit_distance,
			0.0,
			TAU,
			64,
			Color(0.3, 0.3, 0.3, 0.5),
			1.0
		)

		# Position de la planète
		var planet_position: Vector2 = Vector2(
			cos(angle) * orbit_distance,
			sin(angle) * orbit_distance
		)

		# Planète
		draw_circle(
			planet_position,
			planet.size * 5.0,
			_get_planet_color(planet.type)
		)

		# Lunes
		var moons: Array[Dictionary] = planet.get_meta("moons")

		_draw_moons(
			planet_position,
			moons
		)


func _draw_moons(
	planet_position: Vector2,
	moons: Array[Dictionary]
) -> void:
	for moon in moons:
		var distance: float = moon["distance"]
		var angle: float = moon["angle"]
		var size: float = moon["size"]

		# Orbite de la lune
		draw_arc(
			planet_position,
			distance,
			0.0,
			TAU,
			32,
			Color(0.4, 0.4, 0.4, 0.35),
			1.0
		)

		# Position de la lune
		var moon_position: Vector2 = planet_position + Vector2(
			cos(angle) * distance,
			sin(angle) * distance
		)

		# Lune
		draw_circle(
			moon_position,
			size * 5.0,
			Color(0.75, 0.75, 0.75)
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

		if event.button_index == MOUSE_BUTTON_LEFT:
			_select_planet_at_position(
				get_global_mouse_position()
			)

			get_viewport().set_input_as_handled()

func _select_planet_at_position(mouse_position: Vector2) -> void:
	var closest_planet: PlanetData = null
	var closest_distance: float = INF

	for planet in planets:
		var orbit_distance: float = planet.orbit_distance
		var angle: float = planet.get_meta("angle")

		var planet_position: Vector2 = Vector2(
			cos(angle) * orbit_distance,
			sin(angle) * orbit_distance
		)

		var distance: float = mouse_position.distance_to(
			planet_position
		)

		if distance < closest_distance:
			closest_distance = distance
			closest_planet = planet

	if closest_planet == null:
		return

	var zoom: float = $Camera2D.zoom.x
	var selection_distance: float = 20.0 / zoom

	if closest_distance <= selection_distance:
		planet_selected.emit(closest_planet)
		
func _zoom(factor: float) -> void:
	var new_zoom: float = (
		camera.zoom.x * factor
	)

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
