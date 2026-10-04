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

	stability = rng.randf_range(60.0, 100.0)


func simulate_year(
	civilization_economy: float,
	civilization_technology: float
) -> void:
	# -------------------------------------------------
	# CROISSANCE DE LA POPULATION
	# -------------------------------------------------

	var capacity: int = max(
		population_capacity,
		1
	)

	var population_ratio: float = (
		float(population)
		/ float(capacity)
	)

	var growth_rate: float = 0.01

	# Une économie développée favorise
	# la croissance démographique.
	growth_rate += (
		civilization_economy * 0.00005
	)

	# Une colonie peu développée grandit
	# légèrement plus vite.
	if development < 30.0:
		growth_rate += 0.005

	# La croissance ralentit lorsque la colonie
	# approche de sa capacité.
	if population_ratio > 0.8:
		growth_rate -= (
			(population_ratio - 0.8)
			* 0.04
		)

	growth_rate = clamp(
		growth_rate,
		-0.01,
		0.04
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
		capacity
	)

	# -------------------------------------------------
	# DÉVELOPPEMENT
	# -------------------------------------------------

	var development_growth: float = 0.1

	development_growth += (
		civilization_economy * 0.01
	)

	development_growth += (
		civilization_technology * 0.005
	)

	# Une colonie très stable se développe
	# plus efficacement.
	development_growth += (
		stability * 0.005
	)

	# Une colonie instable subit des ralentissements.
	if stability < 40.0:
		development_growth -= (
			(40.0 - stability)
			* 0.02
		)

	development += development_growth

	development = clamp(
		development,
		0.0,
		100.0
	)

	# -------------------------------------------------
	# PRODUCTION
	# -------------------------------------------------

	production = (
		development * 0.5
	)

	production += (
		civilization_economy * 0.25
	)

	production += (
		civilization_technology * 0.15
	)

	# Une colonie instable produit moins.
	if stability < 50.0:
		production *= (
			0.7
			+ stability * 0.006
		)

	production = clamp(
		production,
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
