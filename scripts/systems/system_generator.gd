class_name SystemGenerator
extends RefCounted


func generate(system_seed: int, star_type: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = system_seed

	var star_luminosity: float = _get_star_luminosity(star_type)

	var planet_count: int = rng.randi_range(1, 8)

	var planets: Array[PlanetData] = []

	for i in planet_count:
		var planet: PlanetData = _generate_planet(
			rng,
			i,
			star_luminosity
		)

		planets.append(planet)

	return {
		"seed": system_seed,
		"star_type": star_type,
		"star_luminosity": star_luminosity,
		"planets": planets,
	}


func _generate_planet(
	rng: RandomNumberGenerator,
	id: int,
	star_luminosity: float
) -> PlanetData:

	var orbit_distance: float = 100.0 + float(id) * 100.0

	orbit_distance += rng.randf_range(-20.0, 20.0)

	var planet_type: String = _generate_planet_type(
		rng,
		orbit_distance,
		star_luminosity
	)

	var size: float = _generate_planet_size(
		rng,
		planet_type
	)

	var moon_count: int = _generate_moon_count(
		rng,
		planet_type
	)

	var planet_seed: int = rng.randi()

	var planet := PlanetData.new()

	planet.initialize(
		id,
		planet_seed,
		planet_type,
		size,
		orbit_distance,
		moon_count,
		star_luminosity
	)

	return planet


func _generate_planet_type(
	rng: RandomNumberGenerator,
	orbit_distance: float,
	star_luminosity: float
) -> String:

	# Distance à laquelle la température serait
	# approximativement similaire à celle de la Terre.
	var habitable_distance: float = sqrt(star_luminosity) * 100.0

	var relative_distance: float = (
		orbit_distance / habitable_distance
	)

	# Très proche de l'étoile.
	if relative_distance < 0.6:
		if rng.randf() < 0.7:
			return "rocky"

		return "desert"

	# Zone intermédiaire.
	if relative_distance < 1.5:
		var roll := rng.randf()

		if roll < 0.4:
			return "rocky"

		if roll < 0.7:
			return "desert"

		return "ocean"

	# Région externe.
	var roll := rng.randf()

	if roll < 0.45:
		return "ice"

	if roll < 0.8:
		return "gas_giant"

	return "ice"


func _generate_planet_size(
	rng: RandomNumberGenerator,
	planet_type: String
) -> float:

	if planet_type == "gas_giant":
		return rng.randf_range(4.0, 12.0)

	return rng.randf_range(0.5, 2.0)


func _generate_moon_count(
	rng: RandomNumberGenerator,
	planet_type: String
) -> int:

	if planet_type == "gas_giant":
		return rng.randi_range(1, 8)

	return rng.randi_range(0, 2)


func _get_star_luminosity(star_type: String) -> float:
	match star_type:
		"red_dwarf":
			return 0.1

		"orange":
			return 0.4

		"yellow":
			return 1.0

		"white":
			return 4.0

		"blue":
			return 20.0

		_:
			return 1.0
