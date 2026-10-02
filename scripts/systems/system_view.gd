extends Node2D

var system: Dictionary = {}
var planets: Array[Dictionary] = []


func set_system(new_system: Dictionary) -> void:
	system = new_system
	planets = system["planets"]

	_initialize_planets()

	queue_redraw()


func _initialize_planets() -> void:
	for planet in planets:
		var orbit_distance: float = planet["orbit_distance"]
		var planet_seed: int = planet["seed"]

		var rng := RandomNumberGenerator.new()
		rng.seed = planet_seed

		planet["angle"] = rng.randf_range(0.0, TAU)
		planet["orbit_speed"] = 80.0 / max(orbit_distance, 50.0)

		_initialize_moons(planet)


func _initialize_moons(planet: Dictionary) -> void:
	var moon_count: int = planet["moons"]
	var planet_seed: int = planet["seed"]
	var planet_size: float = planet["size"]

	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed

	var moons: Array[Dictionary] = []

	for i in moon_count:
		var moon_seed := rng.randi()

		var distance := 18.0 + planet_size * 8.0
		distance += float(i) * 12.0
		distance += rng.randf_range(-3.0, 3.0)

		var size := rng.randf_range(0.15, 0.35)

		var orbit_speed := rng.randf_range(1.0, 2.5)

		var moon := {
			"id": i,
			"seed": moon_seed,
			"distance": distance,
			"size": size,
			"angle": rng.randf_range(0.0, TAU),
			"orbit_speed": orbit_speed
		}

		moons.append(moon)

	planet["moon_data"] = moons


func _process(delta: float) -> void:
	for planet in planets:
		planet["angle"] += planet["orbit_speed"] * delta

		var moons: Array[Dictionary] = planet["moon_data"]

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
		var orbit_distance: float = planet["orbit_distance"]
		var planet_size: float = planet["size"]
		var angle: float = planet["angle"]

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
		var position := Vector2(
			cos(angle) * orbit_distance,
			sin(angle) * orbit_distance
		)

		draw_circle(
			position,
			planet_size * 5.0,
			_get_planet_color(planet["type"])
		)

		_draw_moons(
			position,
			planet["moon_data"]
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

		var moon_position := planet_position + Vector2(
			cos(angle) * distance,
			sin(angle) * distance
		)

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
