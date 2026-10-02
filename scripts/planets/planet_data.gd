class_name PlanetData
extends RefCounted


var id: int
var seed: int
var type: String

var size: float
var orbit_distance: float
var moon_count: int

var temperature: float
var gravity: float
var water: float
var atmosphere: float
var habitability: float


func initialize(
	planet_id: int,
	planet_seed: int,
	planet_type: String,
	planet_size: float,
	planet_orbit_distance: float,
	planet_moon_count: int,
	star_luminosity: float
) -> void:
	id = planet_id
	seed = planet_seed
	type = planet_type
	size = planet_size
	orbit_distance = planet_orbit_distance
	moon_count = planet_moon_count

	_generate_physical_properties(star_luminosity)


func _generate_physical_properties(star_luminosity: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Température théorique simplifiée basée sur
	# la luminosité de l'étoile et la distance orbitale.
	var distance_factor := sqrt(
		star_luminosity / max(orbit_distance / 100.0, 0.1)
	)

	temperature = 15.0 + (
		80.0 * distance_factor
	)

	# Variation propre à la planète.
	temperature += rng.randf_range(-15.0, 15.0)

	# Les planètes rocheuses et désertiques ont tendance
	# à être plus chaudes que les planètes riches en glace.
	match type:
		"desert":
			temperature += 20.0

		"ice":
			temperature -= 30.0

		"ocean":
			temperature -= 5.0

		"gas_giant":
			temperature += 10.0

	# Gravité.
	gravity = size * rng.randf_range(0.7, 1.3)

	# Eau.
	match type:
		"desert":
			water = rng.randf_range(0.0, 30.0)

		"ocean":
			water = rng.randf_range(60.0, 100.0)

		"ice":
			water = rng.randf_range(30.0, 90.0)

		"rocky":
			water = rng.randf_range(5.0, 70.0)

		"gas_giant":
			water = rng.randf_range(0.0, 20.0)

		_:
			water = rng.randf_range(0.0, 100.0)

	# Atmosphère.
	match type:
		"gas_giant":
			atmosphere = rng.randf_range(80.0, 100.0)

		"rocky":
			atmosphere = rng.randf_range(20.0, 80.0)

		"desert":
			atmosphere = rng.randf_range(10.0, 50.0)

		"ocean":
			atmosphere = rng.randf_range(40.0, 90.0)

		"ice":
			atmosphere = rng.randf_range(5.0, 60.0)

		_:
			atmosphere = rng.randf_range(0.0, 100.0)

	habitability = _calculate_habitability()


func _calculate_habitability() -> float:
	# Les géantes gazeuses ne sont pas habitables
	# directement à leur surface.
	if type == "gas_giant":
		return 0.0

	var score := 100.0

	# Température idéale autour de 15 °C.
	score -= abs(temperature - 15.0) * 0.5

	# Gravité idéale autour de 1 G.
	score -= abs(gravity - 1.0) * 30.0

	# Une quantité d'eau modérée est favorable.
	score -= abs(water - 50.0) * 0.2

	# Une atmosphère modérée est préférable.
	score -= abs(atmosphere - 60.0) * 0.2

	return clamp(score, 0.0, 100.0)