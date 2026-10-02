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
	planet_moon_count: int
) -> void:
	id = planet_id
	seed = planet_seed
	type = planet_type
	size = planet_size
	orbit_distance = planet_orbit_distance
	moon_count = planet_moon_count

	_generate_physical_properties()


func _generate_physical_properties() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	temperature = rng.randf_range(-100.0, 150.0)
	gravity = size * rng.randf_range(0.7, 1.3)
	water = rng.randf_range(0.0, 100.0)
	atmosphere = rng.randf_range(0.0, 100.0)

	habitability = _calculate_habitability()


func _calculate_habitability() -> float:
	var score := 100.0

	# Température idéale autour de 15 °C.
	score -= abs(temperature - 15.0) * 0.5

	# Une gravité trop éloignée de 1 G réduit l'habitabilité.
	score -= abs(gravity - 1.0) * 30.0

	# L'eau est favorable, mais une planète totalement couverte
	# d'eau ou complètement sèche est moins idéale.
	score -= abs(water - 50.0) * 0.2

	# Une atmosphère modérée est préférable.
	score -= abs(atmosphere - 60.0) * 0.2

	return clamp(score, 0.0, 100.0)
