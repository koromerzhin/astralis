class_name SystemGenerator
extends RefCounted


func generate(system_seed: int, star_type: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = system_seed

	var planet_count := rng.randi_range(1, 8)

	var planets: Array[Dictionary] = []

	for i in planet_count:
		planets.append(_generate_planet(rng, i))

	return {
		"seed": system_seed,
		"star_type": star_type,
		"planets": planets,
	}


func _generate_planet(
	rng: RandomNumberGenerator,
	id: int
) -> Dictionary:
	var planet_types := [
		"rocky",
		"desert",
		"ocean",
		"ice",
		"gas_giant"
	]

	var planet_type: String = planet_types[
		rng.randi_range(0, planet_types.size() - 1)
	]

	var orbit_distance := 100.0 + float(id) * 100.0
	orbit_distance += rng.randf_range(-20.0, 20.0)

	var size := rng.randf_range(0.5, 2.0)

	var moon_count := 0

	if planet_type == "gas_giant":
		moon_count = rng.randi_range(1, 6)
	else:
		moon_count = rng.randi_range(0, 2)

	return {
		"id": id,
		"type": planet_type,
		"orbit_distance": orbit_distance,
		"size": size,
		"moons": moon_count,
	}
