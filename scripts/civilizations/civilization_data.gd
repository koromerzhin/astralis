class_name CivilizationData
extends RefCounted


var id: int
var global_id: int
var seed: int

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

var trade_income: float = 0.0


func initialize(
	civilization_id: int,
	civilization_seed: int,
	planet_id: int,
	planet_minerals: float,
	planet_energy: float,
	planet_biological_resources: float,
	planet_habitability: float
) -> void:
	id = civilization_id
	seed = civilization_seed
	home_planet_id = planet_id

	colony_planet_ids.clear()
	colonies.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	name = _generate_name(rng)

	population = rng.randi_range(
		100000,
		10000000
	)

	age = rng.randf_range(
		100.0,
		10000.0
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

	space_capability = _calculate_space_capability()

	military_power = _calculate_military_power(
		rng
	)


func initialize_from_rebellion(
	civilization_id: int,
	civilization_seed: int,
	target_planet: PlanetData,
	colony: ColonyData,
	former_civilization: CivilizationData
) -> void:
	id = civilization_id
	seed = civilization_seed

	home_planet_id = (
		target_planet.global_id
	)

	colony_planet_ids.clear()
	colonies.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	name = _generate_name(rng)

	population = max(
		1,
		int(
			float(colony.population)
			* rng.randf_range(
				0.7,
				0.95
			)
		)
	)

	population = min(
		population,
		target_planet.population_capacity
	)

	age = rng.randf_range(
		10.0,
		500.0
	)

	var development_factor: float = clamp(
		colony.development / 100.0,
		0.0,
		1.0
	)

	var stability_factor: float = clamp(
		colony.stability / 100.0,
		0.0,
		1.0
	)

	technology = (
		former_civilization.technology
		* 0.70
		+ development_factor * 30.0
	)

	technology *= rng.randf_range(
		0.90,
		1.05
	)

	technology = clamp(
		technology,
		1.0,
		100.0
	)

	economy = (
		colony.production * 0.60
		+ former_civilization.economy * 0.25
		+ target_planet.habitability * 0.15
	)

	economy *= rng.randf_range(
		0.85,
		1.05
	)

	economy = clamp(
		economy,
		1.0,
		100.0
	)

	space_capability = (
		_calculate_space_capability()
	)

	military_power = (
		former_civilization.military_power * 0.50
		+ colony.production * 0.20
		+ technology * 0.20
		+ stability_factor * 10.0
	)

	military_power *= rng.randf_range(
		0.85,
		1.0
	)

	military_power = clamp(
		military_power,
		1.0,
		100.0
	)


func simulate_year(
	planet_habitability: float,
	planet_population_capacity: int
) -> void:
	var growth_rate: float = 0.0

	# Économie
	growth_rate += (
		economy * 0.00002
	)

	# Habitabilité
	growth_rate += (
		planet_habitability * 0.00001
	)

	# Technologie
	growth_rate += (
		technology * 0.00001
	)

	# Colonies
	growth_rate += (
		colony_planet_ids.size()
		* 0.0005
	)

	# Production des colonies
	growth_rate += (
		get_total_production()
		* 0.00001
	)

	# Bonus lié au niveau économique
	var stability_bonus: float = (
		(economy / 100.0)
		* 0.002
	)

	growth_rate += stability_bonus

	# Surpopulation
	var population_ratio: float = (
		float(population)
		/ float(
			max(
				planet_population_capacity,
				1
			)
		)
	)

	if population_ratio > 0.8:
		var overcrowding: float = (
			(population_ratio - 0.8)
			* 0.05
		)

		growth_rate -= overcrowding

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

	population = min(
		population,
		max(
			planet_population_capacity,
			1
		)
	)

	simulate_colonies()


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

	economy += (
		economy_target - economy
	) * 0.01

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

	space_capability = (
		_calculate_space_capability()
	)

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


func _calculate_technology(
	civilization_age: float,
	planet_habitability: float,
	rng: RandomNumberGenerator
) -> float:
	var value: float = 0.0

	value += min(
		civilization_age / 100.0,
		60.0
	)

	value += (
		planet_habitability * 0.25
	)

	value += rng.randf_range(
		-10.0,
		10.0
	)

	return clamp(
		value,
		1.0,
		100.0
	)


func _calculate_economy(
	planet_minerals: float,
	planet_energy: float,
	planet_biological_resources: float,
	planet_habitability: float
) -> float:
	var value: float = 0.0

	value += (
		planet_minerals * 0.35
	)

	value += (
		planet_energy * 0.30
	)

	value += (
		planet_biological_resources * 0.15
	)

	value += (
		planet_habitability * 0.20
	)

	return clamp(
		value,
		1.0,
		100.0
	)


func _calculate_space_capability() -> float:
	var capability: float = 0.0

	capability += (
		technology * 0.65
	)

	capability += (
		economy * 0.25
	)

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


func _calculate_military_power(
	rng: RandomNumberGenerator
) -> float:
	var military: float = 0.0

	military += (
		technology * 0.45
	)

	military += (
		economy * 0.30
	)

	military += (
		space_capability * 0.25
	)

	military += rng.randf_range(
		-10.0,
		10.0
	)

	return clamp(
		military,
		1.0,
		100.0
	)


func get_space_stage() -> String:
	if space_capability < 20.0:
		return "planetary"

	if space_capability < 50.0:
		return "orbital"

	if space_capability < 75.0:
		return "interplanetary"

	return "interstellar"


func get_interaction_range() -> float:
	var space_stage: String = (
		get_space_stage()
	)

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


func add_colony(
	colony_seed: int,
	target_planet: PlanetData
) -> void:
	if target_planet == null:
		return

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


func add_trade_income(
	value: float
) -> void:
	trade_income += value


func remove_colony(
	planet_id: int
) -> ColonyData:
	for i in colonies.size():
		var colony: ColonyData = (
			colonies[i]
		)

		if colony.planet_id != planet_id:
			continue

		colonies.remove_at(i)

		colony_planet_ids.erase(
			planet_id
		)

		return colony

	return null


func take_over_colony(
	colony: ColonyData
) -> void:
	if colony == null:
		return

	if colony_planet_ids.has(
		colony.planet_id
	):
		return

	colony_planet_ids.append(
		colony.planet_id
	)

	colonies.append(
		colony
	)


func simulate_colonies() -> void:
	for colony in colonies:
		if not colony.is_occupied():
			continue

		if colony.stability >= 70.0:
			colony.annex()


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


func apply_military_losses(
	amount: float
) -> void:
	military_power -= amount

	military_power = clamp(
		military_power,
		1.0,
		100.0
	)


func _generate_name(
	rng: RandomNumberGenerator
) -> String:
	var prefixes := [
		"Al",
		"Bel",
		"Kor",
		"Nar",
		"Vel",
		"Tar",
		"Zor",
		"Kal",
		"Mer",
		"Sol"
	]

	var suffixes := [
		"ans",
		"iens",
		"ites",
		"ari",
		"ori",
		"ons",
		"es",
		"aks",
		"ums",
		"ens"
	]

	var prefix: String = (
		prefixes[
			rng.randi_range(
				0,
				prefixes.size() - 1
			)
		]
	)

	var suffix: String = (
		suffixes[
			rng.randi_range(
				0,
				suffixes.size() - 1
			)
		]
	)

	return prefix + suffix
