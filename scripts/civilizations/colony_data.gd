class_name ColonyData
extends RefCounted


var id: int
var planet_id: int

var population: int

var development: float
var production: float
var stability: float

var seed: int


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

	population = rng.randi_range(
		1000,
		100000
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

	development += (
		civilization_technology * 0.002
	)

	development = clamp(
		development,
		0.0,
		100.0
	)

	production = (
		development * 0.5
		+ civilization_economy * 0.3
	)

	production = clamp(
		production,
		0.0,
		100.0
	)

	stability += 0.1

	stability = clamp(
		stability,
		0.0,
		100.0
	)
