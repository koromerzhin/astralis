class_name PlanetData
extends RefCounted


var id: int
var seed: int
var type: String
var size: float
var orbit_distance: float
var moon_count: int


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