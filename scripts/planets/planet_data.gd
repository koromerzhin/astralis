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
var in_habitable_zone: bool
var habitability: float

var has_life: bool
var life_level: float
var life_stage: String
var civilization: CivilizationData
var minerals: float
var energy: float
var biological_resources: float

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
	_generate_life()
	_generate_civilization()
	_generate_resources()

func _generate_life() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	has_life = false
	life_level = 0.0
	life_stage = "none"

	if type == "gas_giant":
		return

	var life_probability: float

	if in_habitable_zone:
		life_probability = habitability / 100.0
	else:
		life_probability = habitability / 500.0

	if rng.randf() > life_probability:
		return

	has_life = true

	life_level = rng.randf_range(10.0, 100.0)

	life_level *= habitability / 100.0

	life_level = clamp(
		life_level,
		1.0,
		100.0
	)

	if life_level < 35.0:
		life_stage = "primitive"

	elif life_level < 75.0:
		life_stage = "complex"

	else:
		life_stage = "intelligent"

func _generate_physical_properties(star_luminosity: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Température théorique simplifiée basée sur
	# la luminosité de l'étoile et la distance orbitale.
	var distance_factor := sqrt(
		star_luminosity / max(orbit_distance / 100.0, 0.1)
	)

	var habitable_distance: float = sqrt(star_luminosity) * 100.0

	in_habitable_zone = (
		orbit_distance >= habitable_distance * 0.6
		and orbit_distance <= habitable_distance * 1.5
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
	if type == "gas_giant":
		return 0.0

	if not in_habitable_zone:
		return 0.0

	var score: float = 100.0

	score -= abs(temperature - 15.0) * 0.5
	score -= abs(gravity - 1.0) * 30.0
	score -= abs(water - 50.0) * 0.2
	score -= abs(atmosphere - 60.0) * 0.2

	return clamp(score, 0.0, 100.0)

func _generate_civilization() -> void:
	civilization = null

	if life_stage != "intelligent":
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Toutes les espèces intelligentes ne développent
	# pas nécessairement une civilisation.
	var civilization_probability: float = (
		habitability / 100.0
	)

	if rng.randf() > civilization_probability:
		return

	var civilization_seed: int = rng.randi()

	civilization = CivilizationData.new()

	civilization.initialize(
		id,
		civilization_seed,
		id
	)

func _generate_resources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Ressources minérales.
	match type:
		"rocky":
			minerals = rng.randf_range(50.0, 100.0)

		"desert":
			minerals = rng.randf_range(40.0, 90.0)

		"ocean":
			minerals = rng.randf_range(20.0, 70.0)

		"ice":
			minerals = rng.randf_range(30.0, 80.0)

		"gas_giant":
			minerals = rng.randf_range(10.0, 50.0)

		_:
			minerals = rng.randf_range(0.0, 100.0)

	# Ressources énergétiques.
	match type:
		"desert":
			energy = rng.randf_range(50.0, 100.0)

		"ocean":
			energy = rng.randf_range(30.0, 80.0)

		"ice":
			energy = rng.randf_range(20.0, 60.0)

		"gas_giant":
			energy = rng.randf_range(60.0, 100.0)

		"rocky":
			energy = rng.randf_range(30.0, 70.0)

		_:
			energy = rng.randf_range(0.0, 100.0)

	# Ressources biologiques.
	if has_life:
		biological_resources = rng.randf_range(40.0, 100.0)

		# Une vie complexe produit généralement
		# davantage de ressources biologiques.
		if life_stage == "complex":
			biological_resources += 10.0

		elif life_stage == "intelligent":
			biological_resources += 20.0
	else:
		biological_resources = rng.randf_range(0.0, 20.0)

	biological_resources = clamp(
		biological_resources,
		0.0,
		100.0
	)
