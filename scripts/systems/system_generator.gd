class_name SystemGenerator
extends RefCounted


func generate(system_seed: int, star_type: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = system_seed

	var planet_count := rng.randi_range(1, 8)

	var planets: Array[PlanetData] = []

	for i in planet_count:
		var planet := _generate_planet(rng, i)
		planets.append(planet)

	return {
		"seed": system_seed,
		"star_type": star_type,
		"planets": planets,
	}


func _generate_planet(
	rng: RandomNumberGenerator,
	id: int
) -> PlanetData:
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

	var orbit_distance: float = 100.0 + float(id) * 100.0
	orbit_distance += rng.randf_range(-20.0, 20.0)

	var size: float = rng.randf_range(0.5, 2.0)

	var moon_count := 0

	if planet_type == "gas_giant":
		moon_count = rng.randi_range(1, 6)
	else:
		moon_count = rng.randi_range(0, 2)

	var planet_seed: int = rng.randi()

	var planet := PlanetData.new()

	planet.initialize(
		id,
		planet_seed,
		planet_type,
		size,
		orbit_distance,
		moon_count
	)

	return planet