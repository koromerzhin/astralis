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
var habitability: float
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

	habitability = target_planet.habitability

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

func occupy() -> void:
	political_status = STATUS_OCCUPIED


func annex() -> void:
	political_status = STATUS_ANNEXED


func is_occupied() -> bool:
	return political_status == STATUS_OCCUPIED


func is_annexed() -> bool:
	return political_status == STATUS_ANNEXED

func simulate_stability(
	civilization_economy: float,
	civilization_technology: float
) -> void:
	var stability_change: float = 0.0

	# -------------------------------------------------
	# DÉVELOPPEMENT
	# -------------------------------------------------

	stability_change += (
		development - 50.0
	) * 0.02

	# -------------------------------------------------
	# ÉCONOMIE
	# -------------------------------------------------

	stability_change += (
		civilization_economy - 50.0
	) * 0.015

	# -------------------------------------------------
	# TECHNOLOGIE
	# -------------------------------------------------

	stability_change += (
		civilization_technology - 50.0
	) * 0.01

	# -------------------------------------------------
	# PRESSION DÉMOGRAPHIQUE
	# -------------------------------------------------

	if population_capacity > 0:
		var population_ratio: float = (
			float(population)
			/ float(population_capacity)
		)

		if population_ratio > 0.8:
			stability_change -= (
				population_ratio - 0.8
			) * 10.0

	# -------------------------------------------------
	# STATUT POLITIQUE
	# -------------------------------------------------

	match political_status:
		STATUS_NORMAL:
			stability_change += 0.5

		STATUS_OCCUPIED:
			stability_change -= 2.0

		STATUS_ANNEXED:
			stability_change -= 0.5

	# -------------------------------------------------
	# APPLICATION
	# -------------------------------------------------

	stability += stability_change

	stability = clamp(
		stability,
		0.0,
		100.0
	)

func set_occupied() -> void:
	political_status = STATUS_OCCUPIED

	stability = min(
		stability,
		40.0
	)

func update_political_status() -> void:
	match political_status:
		STATUS_OCCUPIED:
			if stability >= 70.0:
				political_status = STATUS_ANNEXED

		STATUS_ANNEXED:
			if stability >= 85.0:
				political_status = STATUS_NORMAL

func simulate_year(
	civilization_economy: float,
	civilization_technology: float
) -> void:
	if population <= 0:
		population = 100
		return

	var habitability_factor: float = (
		habitability / 100.0
	)

	var stability_factor: float = (
		stability / 100.0
	)

	var economy_factor: float = (
		civilization_economy / 100.0
	)

	var technology_factor: float = (
		civilization_technology / 100.0
	)

	var growth_rate: float = 0.01

	growth_rate += (
		habitability_factor * 0.02
	)

	growth_rate += (
		stability_factor * 0.01
	)

	growth_rate += (
		economy_factor * 0.005
	)

	growth_rate += (
		technology_factor * 0.005
	)

	var growth: int = int(
		population * growth_rate
	)

	population += max(
		growth,
		1
	)

	population = min(
		population,
		population_capacity
	)

func simulate_production(
	civilization_economy: float,
	civilization_technology: float
) -> void:
	var stability_factor: float = (
		stability / 100.0
	)

	var economy_factor: float = (
		civilization_economy / 100.0
	)

	var technology_factor: float = (
		civilization_technology / 100.0
	)

	var production_growth: float = 0.0

	production_growth += (
		development * 0.05
	)

	production_growth += (
		stability_factor * 2.0
	)

	production_growth += (
		economy_factor * 3.0
	)

	production_growth += (
		technology_factor * 2.0
	)

	production += production_growth

	production = clamp(
		production,
		0.0,
		100.0
	)

func simulate_development(
	civilization_technology: float
) -> void:
	var development_change: float = 0.0

	# La production permet de financer les infrastructures.
	development_change += (
		production * 0.02
	)

	# Une forte stabilité facilite le développement.
	development_change += (
		stability * 0.01
	)

	# Une population importante fournit
	# davantage de main-d'œuvre.
	if population_capacity > 0:
		var population_ratio: float = clamp(
			float(population)
			/ float(population_capacity),
			0.0,
			1.0
		)

		development_change += (
			population_ratio * 0.5
		)

	# Une civilisation technologiquement avancée
	# développe plus rapidement ses colonies.
	development_change += (
		civilization_technology * 0.01
	)

	development += development_change

	development = clamp(
		development,
		0.0,
		100.0
	)

func calculate_technology_contribution() -> float:
	var development_factor: float = (
		development / 100.0
	)

	var stability_factor: float = (
		stability / 100.0
	)

	var population_factor: float = 0.0

	if population_capacity > 0:
		population_factor = clamp(
			float(population)
			/ float(population_capacity),
			0.0,
			1.0
		)

	var contribution: float = 0.0

	contribution += (
		development_factor * 0.05
	)

	contribution += (
		stability_factor * 0.025
	)

	contribution += (
		population_factor * 0.025
	)

	return contribution

func check_revolt() -> bool:
	if political_status == STATUS_ANNEXED:
		return false

	if stability >= 20.0:
		return false

	var revolt_chance: float = (
		(20.0 - stability) / 20.0
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = (
		seed
		+ population
		+ int(development * 100.0)
	)

	return rng.randf() < revolt_chance

func can_become_independent() -> bool:
	if political_status != STATUS_OCCUPIED:
		return false

	if stability < 25.0:
		return false

	if development < 20.0:
		return false

	if population < 100:
		return false

	return true
