class_name ColonyData
extends RefCounted


const STATUS_NORMAL := "normal"
const STATUS_OCCUPIED := "occupee"
const STATUS_ANNEXED := "annexee"


var id: int
var planet_id: int

var population: int
var population_capacity: int = 0
var planet_population_capacity: int = 0

var development: float
var production: float
var stability: float

var seed: int

var political_status: String = STATUS_NORMAL


func initialize(
	colony_id: int,
	colony_seed: int,
	target_planet: PlanetData
) -> void:
	id = colony_id
	seed = colony_seed
	planet_id = target_planet.global_id

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	planet_population_capacity = (
		target_planet.population_capacity
	)

	population_capacity = max(
		1000,
		int(
			float(planet_population_capacity)
			* 0.0625
		)
	)

	population = rng.randi_range(
		1000,
		100000
	)

	population = min(
		population,
		population_capacity
	)

	development = rng.randf_range(
		1.0,
		20.0
	)

	production = rng.randf_range(
		5.0,
		30.0
	)

	stability = rng.randf_range(
		60.0,
		100.0
	)


func simulate_year(
	civilization_economy: float,
	civilization_technology: float
) -> void:
	var growth_rate: float = 0.01

	growth_rate += (
		civilization_economy * 0.00005
	)

	growth_rate += (
		development * 0.0001
	)

	growth_rate -= (
		(100.0 - stability) * 0.00005
	)

	if is_occupied():
		growth_rate -= 0.005

	var population_ratio: float = (
		float(population)
		/ float(max(population_capacity, 1))
	)

	if population_ratio > 0.8:
		growth_rate -= (
			(population_ratio - 0.8)
			* 0.05
		)

	growth_rate = clamp(
		growth_rate,
		-0.02,
		0.05
	)

	population = max(
		1,
		int(
			float(population)
			* (1.0 + growth_rate)
		)
	)

	population = min(
		population,
		population_capacity
	)

	development += (
		civilization_technology * 0.002
	)

	if is_occupied():
		development -= 0.1

	development = clamp(
		development,
		0.0,
		100.0
	)

	var capacity_growth: float = (
		development * 0.01
		+ civilization_technology * 0.005
	)

	population_capacity += int(
		capacity_growth
	)

	var technology_factor: float = (
		1.0
		+ civilization_technology / 100.0
	)

	var maximum_capacity: int = int(
		float(planet_population_capacity)
		* technology_factor
	)

	population_capacity = clamp(
		population_capacity,
		1000,
		maximum_capacity
	)

	population = min(
		population,
		population_capacity
	)

	production = (
		development * 0.5
		+ civilization_economy * 0.3
	)

	if is_occupied():
		production *= 0.75

	production = clamp(
		production,
		0.0,
		100.0
	)

	if is_occupied():
		stability -= 0.5
	else:
		stability += 0.1

	stability = clamp(
		stability,
		0.0,
		100.0
	)


func occupy() -> void:
	political_status = STATUS_OCCUPIED


func annex() -> void:
	political_status = STATUS_ANNEXED


func is_occupied() -> bool:
	return political_status == STATUS_OCCUPIED


func is_annexed() -> bool:
	return political_status == STATUS_ANNEXED
