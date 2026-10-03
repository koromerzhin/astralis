class_name CivilizationData
extends RefCounted


var id: int
var global_id: int
var seed: int
var trade_income: float = 0.0
var name: String
var population: int
var technology: float
var economy: float
var space_capability: float
var military_power: float
var age: float
var home_planet_id: int
var colony_planet_ids: Array[int] = []
var colonies: Array[ColonyData] = []

func initialize(
	civilization_id: int,
	civilization_seed: int,
	planet_id: int,
	planet_minerals: float,
	planet_energy: float,
	planet_biological_resources: float,
	planet_habitability: float
) -> void:
	colony_planet_ids.clear()
	colonies.clear()
	id = civilization_id
	seed = civilization_seed
	home_planet_id = planet_id

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	name = _generate_name(rng)

	population = rng.randi_range(
		100000,
		10000000
	)

	technology = _calculate_technology(
		age,
		planet_habitability,
		rng
	)

	economy = _calculate_economy(
		planet_minerals,
		planet_energy,
		planet_biological_resources,
		planet_habitability
	)

	age = rng.randf_range(
		100.0,
		10000.0
	)

	space_capability = _calculate_space_capability()
	military_power = _calculate_military_power(rng)

func _calculate_space_capability() -> float:
	var capability: float = 0.0

	capability += technology * 0.65
	capability += economy * 0.25

	capability += min(
		age / 1000.0,
		10.0
	)

	capability += (
		colony_planet_ids.size() * 2.0
	)

	return clamp(
		capability,
		0.0,
		100.0
	)

func _generate_name(rng: RandomNumberGenerator) -> String:
	var prefixes := [
		"Al",
		"Ka",
		"Zor",
		"Vel",
		"Tar",
		"Kor",
		"Xan",
		"Mer",
		"Sol",
		"Nex"
	]

	var suffixes := [
		"ia",
		"on",
		"ar",
		"us",
		"ea",
		"or",
		"is",
		"an"
	]

	var prefix: String = prefixes[
		rng.randi_range(
			0,
			prefixes.size() - 1
		)
	]

	var suffix: String = suffixes[
		rng.randi_range(
			0,
			suffixes.size() - 1
		)
	]

	return prefix + suffix

func get_space_stage() -> String:
	if space_capability < 20.0:
		return "planetary"

	if space_capability < 50.0:
		return "orbital"

	if space_capability < 75.0:
		return "interplanetary"

	return "interstellar"

func _calculate_economy(
	planet_minerals: float,
	planet_energy: float,
	planet_biological_resources: float,
	planet_habitability: float
) -> float:

	var resource_score: float = (
		planet_minerals * 0.35
		+ planet_energy * 0.30
		+ planet_biological_resources * 0.15
	)

	var habitability_score: float = (
		planet_habitability * 0.20
	)

	var economy_score: float = (
		resource_score
		+ habitability_score
	)

	# Une petite variation déterministe
	# évite que deux planètes identiques
	# donnent exactement la même économie.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	economy_score += rng.randf_range(
		-5.0,
		5.0
	)

	return clamp(
		economy_score,
		1.0,
		100.0
	)

func _calculate_technology(
	civilization_age: float,
	planet_habitability: float,
	rng: RandomNumberGenerator
) -> float:

	# Une civilisation très ancienne a eu davantage
	# de temps pour accumuler des connaissances.
	var age_factor: float = min(
		civilization_age / 10000.0,
		1.0
	)

	var technology_score: float = (
		age_factor * 70.0
	)

	# Une planète très favorable facilite généralement
	# le développement d'une civilisation complexe.
	technology_score += (
		planet_habitability * 0.20
	)

	# Variation individuelle.
	technology_score += rng.randf_range(
		-15.0,
		15.0
	)

	return clamp(
		technology_score,
		1.0,
		100.0
	)

func simulate_year(planet_habitability: float) -> void:
	var growth_rate: float = 0.0

	# Une économie développée favorise la croissance.
	growth_rate += economy * 0.00002

	# Une planète habitable favorise la croissance.
	growth_rate += planet_habitability * 0.00001

	# La technologie améliore progressivement
	# les conditions de vie.
	growth_rate += technology * 0.00001

	# Les colonies apportent une capacité
	# supplémentaire à la civilisation.
	growth_rate += (
		colony_planet_ids.size() * 0.0005
	)

	# Limitation de la croissance annuelle.
	growth_rate = clamp(
		growth_rate,
		-0.01,
		0.04
	)

	var new_population: float = (
		float(population)
		* (1.0 + growth_rate)
	)

	population = max(
		1,
		int(new_population)
	)

func simulate_economy_and_technology(
	planet_habitability: float,
	planet_minerals: float,
	planet_energy: float,
	planet_biological_resources: float
) -> void:
	var resource_score: float = (
		planet_minerals * 0.35
		+ planet_energy * 0.30
		+ planet_biological_resources * 0.15
	)

	var colony_bonus: float = (
		colony_planet_ids.size() * 3.0
	)

	var production_bonus: float = (
		get_total_production() * 0.10
	)

	var trade_bonus: float = (
		trade_income * 0.10
	)

	var economy_target: float = (
		resource_score
		+ planet_habitability * 0.20
		+ colony_bonus
		+ production_bonus
		+ trade_bonus
	)

	# Une économie évolue progressivement vers son potentiel.
	economy += (
		economy_target - economy
	) * 0.01

	# Une économie forte accélère légèrement
	# le développement technologique.
	var technology_growth: float = (
		(economy / 100.0) * 0.15
		+ (population / 10000000.0) * 0.05
		+ (get_total_production() / 100.0) * 0.05
	)

	technology += technology_growth

	technology = clamp(
		technology,
		1.0,
		100.0
	)

	economy = clamp(
		economy,
		1.0,
		100.0
	)

	space_capability = _calculate_space_capability()
	military_power += (
		technology * 0.01
		+ economy * 0.005
		+ space_capability * 0.005
	)

	military_power = clamp(
		military_power,
		1.0,
		100.0
	)

func add_colony(
	colony_seed: int,
	target_planet: PlanetData
) -> void:
	if colony_planet_ids.has(
		target_planet.global_id
	):
		return

	colony_planet_ids.append(
		target_planet.global_id
	)

	var colony := ColonyData.new()

	colony.initialize(
		colonies.size(),
		colony_seed,
		target_planet
	)

	colonies.append(
		colony
	)

func get_total_population() -> int:
	var total: int = population

	for colony in colonies:
		total += colony.population

	return total

func get_total_production() -> float:
	var total: float = 0.0

	for colony in colonies:
		total += colony.production

	return total

func reset_trade_income() -> void:
	trade_income = 0.0


func add_trade_income(value: float) -> void:
	trade_income += value

func get_interaction_range() -> float:
	var space_stage: String = get_space_stage()

	match space_stage:
		"planetary":
			return 50.0

		"orbital":
			return 150.0

		"interplanetary":
			return 400.0

		"interstellar":
			return 800.0

		_:
			return 50.0

func apply_war_effect() -> void:
	economy -= 2.0

	technology -= 0.2

	economy = clamp(
		economy,
		1.0,
		100.0
	)

	technology = clamp(
		technology,
		1.0,
		100.0
	)

func _calculate_military_power(
	rng: RandomNumberGenerator
) -> float:
	var military: float = 0.0

	military += technology * 0.45
	military += economy * 0.30
	military += space_capability * 0.25

	military += rng.randf_range(
		-10.0,
		10.0
	)

	return clamp(
		military,
		1.0,
		100.0
	)

func apply_military_losses(
	amount: float
) -> void:
	military_power -= amount

	military_power = clamp(
		military_power,
		1.0,
		100.0
	)

func remove_colony(
	planet_id: int
) -> ColonyData:
	for i in colonies.size():
		var colony: ColonyData = colonies[i]

		if colony.planet_id != planet_id:
			continue

		colonies.remove_at(i)
		colony_planet_ids.erase(planet_id)

		return colony

	return null

func take_over_colony(
	colony: ColonyData
) -> void:
	if colony == null:
		return

	if colony_planet_ids.has(colony.planet_id):
		return

	colony_planet_ids.append(
		colony.planet_id
	)

	colonies.append(
		colony
	)
