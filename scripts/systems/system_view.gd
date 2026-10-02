extends Node2D

signal planet_selected(planet: PlanetData)

var system: Dictionary = {}
var planets: Array[PlanetData] = []


func set_system(new_system: Dictionary) -> void:
	system = new_system
	planets = system["planets"]

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
	for planet in planets:
		var angle: float = planet.get_meta("angle")
		var orbit_speed: float = planet.get_meta("orbit_speed")

		angle += orbit_speed * delta

		planet.set_meta("angle", angle)

		var moons: Array[Dictionary] = planet.get_meta("moons")

		for moon in moons:
			moon["angle"] += moon["orbit_speed"] * delta

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


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		if event.pressed:
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