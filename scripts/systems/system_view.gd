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

		var rng := RandomNumberGenerator.new()
		rng.seed = system["seed"] + planet["id"]

		planet["angle"] = rng.randf_range(0.0, TAU)

		# Les planètes proches tournent plus rapidement.
		planet["orbit_speed"] = 80.0 / max(orbit_distance, 50.0)


func _process(delta: float) -> void:
	for planet in planets:
		planet["angle"] += planet["orbit_speed"] * delta

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

		# Orbite
		draw_arc(
			Vector2.ZERO,
			orbit_distance,
			0.0,
			TAU,
			64,
			Color(0.3, 0.3, 0.3, 0.5),
			1.0
		)

		# Position actuelle de la planète
		var position := Vector2(
			cos(angle) * orbit_distance,
			sin(angle) * orbit_distance
		)

		draw_circle(
			position,
			planet_size * 5.0,
			_get_planet_color(planet["type"])
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
