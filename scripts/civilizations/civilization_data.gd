class_name CivilizationData
extends RefCounted


var id: int
var global_id: int
var seed: int
var name: String
var aggression: float = 50.0
var expansionism: float = 50.0
var militarism: float = 50.0
var diplomacy: float = 50.0
var commerce: float = 50.0
var science: float = 50.0
var isolationism: float = 50.0
var population: int
var technology: float
var economy: float
var space_capability: float
var military_power: float
var age: float
var home_planet_id: int
var colony_planet_ids: Array[int] = []
var explored_system_ids: Array[int] = []
var known_civilization_ids: Array[int] = []
var colonies: Array[ColonyData] = []
var trade_income: float = 0.0
var colony_income: float = 0.0
var expansion_budget: float = 0.0
var known_civilization_system_ids: Dictionary = {}

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

	_generate_personality(
		civilization_seed
	)
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
	var population_capacity: int = max(
		planet_population_capacity,
		1
	)

	var population_ratio: float = (
		float(population)
		/ float(population_capacity)
	)

	var growth_rate: float = 0.0

	# Croissance naturelle.
	growth_rate += 0.01

	# Une économie développée améliore les conditions de vie.
	growth_rate += (
		economy * 0.00002
	)

	# La technologie améliore progressivement
	# la croissance démographique.
	growth_rate += (
		technology * 0.00001
	)

	# Une forte densité réduit la croissance.
	if population_ratio > 0.8:
		growth_rate -= (
			(population_ratio - 0.8)
			* 0.04
		)

	# Une population proche de la capacité
	# ne peut pratiquement plus progresser.
	if population_ratio >= 1.0:
		growth_rate = min(
			growth_rate,
			0.001
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
		population_capacity
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


func reset_trarelation_datade_income() -> void:
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
		if colony == null:
			continue

		# -------------------------------------------------
		# ÉVOLUTION DE LA COLONIE
		# -------------------------------------------------

		colony.simulate_year(
			economy,
			technology
		)

		# -------------------------------------------------
		# STABILITÉ POLITIQUE
		# -------------------------------------------------

		colony.simulate_stability(
			economy,
			technology
		)

		# -------------------------------------------------
		# ÉVOLUTION DU STATUT POLITIQUE
		# -------------------------------------------------

		colony.update_political_status()

		# -------------------------------------------------
		# PRODUCTION DE LA COLONIE
		# -------------------------------------------------

		economy += (
			colony.production * 0.01
		)

		# -------------------------------------------------
		# RECHERCHE TECHNOLOGIQUE
		# -------------------------------------------------

		technology += (
			float(colony.population)
			/ 100000000.0
		)

		# -------------------------------------------------
		# BONUS DE STABILITÉ
		# -------------------------------------------------

		if colony.stability >= 70.0:
			economy += 0.05

		# -------------------------------------------------
		# LIMITES
		# -------------------------------------------------

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

func reset_trade_income() -> void:
	trade_income = 0.0

func has_colony(
	planet_id: int
) -> bool:
	return colony_planet_ids.has(
		planet_id
	)

func _generate_personality(
	civilization_seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = civilization_seed

	aggression = rng.randf_range(
		10.0,
		90.0
	)

	expansionism = rng.randf_range(
		10.0,
		90.0
	)

	militarism = rng.randf_range(
		10.0,
		90.0
	)

	diplomacy = rng.randf_range(
		10.0,
		90.0
	)

	commerce = rng.randf_range(
		10.0,
		90.0
	)

	science = rng.randf_range(
		10.0,
		90.0
	)

	isolationism = rng.randf_range(
		10.0,
		90.0
	)

func get_colonization_desire() -> float:
	var desire: float = 0.0

	desire += expansionism * 0.55
	desire += science * 0.15
	desire += economy * 0.10
	desire += space_capability * 0.10

	desire -= isolationism * 0.20

	return clamp(
		desire,
		0.0,
		100.0
	)

func get_personality_type() -> String:
	var scores := {
		"militariste": (
			aggression * 0.5
			+ militarism * 0.5
		),
		"expansionniste": (
			expansionism * 0.6
			+ aggression * 0.2
			+ science * 0.2
		),
		"marchande": (
			commerce * 0.6
			+ diplomacy * 0.3
			+ science * 0.1
		),
		"scientifique": (
			science * 0.7
			+ diplomacy * 0.2
			+ commerce * 0.1
		),
		"diplomatique": (
			diplomacy * 0.6
			+ commerce * 0.2
			+ isolationism * 0.2
		),
		"isolationniste": (
			isolationism * 0.8
			+ diplomacy * 0.1
			+ science * 0.1
		)
	}

	var best_type: String = "neutre"
	var best_score: float = -1.0

	for personality_type in scores:
		var score: float = scores[
			personality_type
		]

		if score > best_score:
			best_score = score
			best_type = personality_type

	return best_type


func get_primary_goal() -> String:
	var goals := {
		"coloniser": (
			expansionism * 0.40
			+ science * 0.15
			+ space_capability * 0.20
			- isolationism * 0.15
		),

		"faire_la_guerre": (
			aggression * 0.40
			+ militarism * 0.40
			+ expansionism * 0.10
			- diplomacy * 0.15
		),

		"commercer": (
			commerce * 0.60
			+ diplomacy * 0.25
			+ economy * 0.15
		),

		"developper_la_science": (
			science * 0.65
			+ technology * 0.20
			+ diplomacy * 0.10
		),

		"creer_des_alliances": (
			diplomacy * 0.60
			+ commerce * 0.20
			+ science * 0.10
		),

		"s_isoler": (
			isolationism * 0.70
			+ science * 0.15
			- expansionism * 0.20
			- aggression * 0.10
		)
	}

	var best_goal: String = "developper_la_science"
	var best_score: float = -INF

	for goal in goals:
		var score: float = goals[goal]

		if score > best_score:
			best_score = score
			best_goal = goal

	return best_goal

func get_secondary_goal() -> String:
	var goals := {
		"coloniser": expansionism
			+ science * 0.25,

		"faire_la_guerre": aggression
			+ militarism * 0.5,

		"commercer": commerce
			+ diplomacy * 0.5,

		"developper_la_science": science
			+ technology * 0.5,

		"creer_des_alliances": diplomacy
			+ commerce * 0.25,

		"s_isoler": isolationism
			- expansionism * 0.25
	}

	var primary_goal: String = get_primary_goal()

	var best_goal: String = "developper_la_science"
	var best_score: float = -INF

	for goal in goals:
		if goal == primary_goal:
			continue

		var score: float = goals[goal]

		if score > best_score:
			best_score = score
			best_goal = goal

	return best_goal

func apply_primary_goal() -> void:
	var goal: String = get_primary_goal()

	match goal:
		"coloniser":
			space_capability += 0.15
			technology += 0.05

		"faire_la_guerre":
			military_power += 0.20
			technology += 0.05

		"commercer":
			economy += 0.20

		"developper_la_science":
			technology += 0.20

		"creer_des_alliances":
			diplomacy += 0.0

		"s_isoler":
			technology += 0.05

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

	military_power = clamp(
		military_power,
		1.0,
		100.0
	)

	space_capability = clamp(
		space_capability,
		0.0,
		100.0
	)

func get_war_desire(
	other_civilization: CivilizationData
) -> float:
	if other_civilization == null:
		return 0.0

	var desire: float = 0.0

	# Agressivité et militarisme constituent la base.
	desire += aggression * 0.40
	desire += militarism * 0.30

	# L'expansionnisme pousse à conquérir.
	desire += expansionism * 0.20

	# La diplomatie réduit l'envie de conflit.
	desire -= diplomacy * 0.20

	# L'isolationnisme réduit également les conflits
	# avec les autres civilisations.
	desire -= isolationism * 0.10

	# Une civilisation technologiquement supérieure
	# est davantage capable de mener une guerre.
	var military_advantage: float = (
		military_power
		- other_civilization.military_power
	)

	desire += clamp(
		military_advantage * 0.20,
		-20.0,
		20.0
	)

	return clamp(
		desire,
		0.0,
		100.0
	)
	
func wants_to_declare_war(
	other_civilization: CivilizationData
) -> bool:
	if other_civilization == null:
		return false

	if other_civilization.global_id == global_id:
		return false

	var desire: float = get_war_desire(
		other_civilization
	)

	if desire < 65.0:
		return false

	if military_power < 20.0:
		return false

	return true

func get_trade_desire(
	other_civilization: CivilizationData
) -> float:
	if other_civilization == null:
		return 0.0

	if other_civilization.global_id == global_id:
		return 0.0

	var desire: float = 0.0

	# Le commerce est le facteur principal.
	desire += commerce * 0.55

	# La diplomatie facilite les échanges.
	desire += diplomacy * 0.20

	# Une économie développée a davantage intérêt
	# à rechercher des partenaires.
	desire += economy * 0.15

	# Les civilisations scientifiques sont légèrement
	# plus ouvertes aux échanges technologiques.
	desire += science * 0.05

	# L'isolationnisme réduit fortement l'intérêt.
	desire -= isolationism * 0.20

	# Une forte agressivité rend les échanges moins
	# prioritaires.
	desire -= aggression * 0.05

	# Un avantage économique augmente légèrement
	# l'intérêt de commercer.
	var economic_difference: float = (
		economy
		- other_civilization.economy
	)

	desire += clamp(
		economic_difference * 0.10,
		-10.0,
		10.0
	)

	return clamp(
		desire,
		0.0,
		100.0
	)

func wants_to_trade(
	other_civilization: CivilizationData
) -> bool:
	if other_civilization == null:
		return false

	if other_civilization.global_id == global_id:
		return false

	var desire: float = get_trade_desire(
		other_civilization
	)

	if desire < 45.0:
		return false

	return true

func get_alliance_desire(
	other_civilization: CivilizationData
) -> float:
	if other_civilization == null:
		return 0.0

	if other_civilization.global_id == global_id:
		return 0.0

	var desire: float = 0.0

	# La diplomatie est le facteur principal.
	desire += diplomacy * 0.55

	# Le commerce crée des intérêts communs.
	desire += commerce * 0.20

	# Les civilisations scientifiques sont légèrement
	# plus favorables aux coopérations.
	desire += science * 0.10

	# Le militarisme réduit l'intérêt pour une alliance
	# pacifique.
	desire -= militarism * 0.10

	# L'agressivité réduit également cette volonté.
	desire -= aggression * 0.10

	# L'isolationnisme est fortement défavorable.
	desire -= isolationism * 0.20

	return clamp(
		desire,
		0.0,
		100.0
	)
	
	
func wants_to_form_alliance(
	other_civilization: CivilizationData
) -> bool:
	if other_civilization == null:
		return false

	if other_civilization.global_id == global_id:
		return false

	var desire: float = (
		get_alliance_desire(
			other_civilization
		)
	)

	if desire < 50.0:
		return false

	return true


func get_exploration_desire() -> float:
	var desire: float = 0.0

	# La science est le facteur principal.
	desire += science * 0.50

	# Une civilisation technologiquement avancée
	# est davantage capable d'explorer.
	desire += technology * 0.20

	# La capacité spatiale est indispensable.
	desire += space_capability * 0.20

	# L'expansionnisme pousse à découvrir de nouveaux territoires.
	desire += expansionism * 0.15

	# L'isolationnisme réduit fortement l'envie d'explorer.
	desire -= isolationism * 0.20

	return clamp(
		desire,
		0.0,
		100.0
	)
	
func wants_to_explore() -> bool:
	if get_space_stage() == "planetary":
		return false

	var desire: float = (
		get_exploration_desire()
	)

	if desire < 40.0:
		return false

	return true
	
func has_explored_system(
	system_id: int
) -> bool:
	return explored_system_ids.has(
		system_id
	)
	
func explore_system(
	system_id: int
) -> void:
	if system_id < 0:
		return

	if explored_system_ids.has(
		system_id
	):
		return

	explored_system_ids.append(
		system_id
	)

func knows_civilization(
	civilization_id: int
) -> bool:
	return known_civilization_ids.has(
		civilization_id
	)
	
func discover_civilization(
	civilization_id: int
) -> void:
	if civilization_id < 0:
		return

	if civilization_id == global_id:
		return

	if known_civilization_ids.has(
		civilization_id
	):
		return

	known_civilization_ids.append(
		civilization_id
	)

func discover_civilization_system(
	civilization_id: int,
	system_id: int
) -> void:
	if civilization_id < 0:
		return

	if system_id < 0:
		return

	if civilization_id == global_id:
		return

	if not known_civilization_system_ids.has(
		civilization_id
	):
		known_civilization_system_ids[
			civilization_id
		] = []

	var known_systems: Array = (
		known_civilization_system_ids[
			civilization_id
		]
	)

	if known_systems.has(system_id):
		return

	known_systems.append(
		system_id
	)
	
func knows_civilization_system(
	civilization_id: int,
	system_id: int
) -> bool:
	if not known_civilization_system_ids.has(
		civilization_id
	):
		return false

	var known_systems: Array = (
		known_civilization_system_ids[
			civilization_id
		]
	)

	return known_systems.has(
		system_id
	)

func simulate_colony_economy() -> void:
	colony_income = 0.0

	for colony in colonies:
		if colony == null:
			continue

		var colony_income_value: float = (
			colony.production
			* 0.5
		)

		if colony.political_status == ColonyData.STATUS_OCCUPIED:
			colony_income_value *= 0.5
		elif colony.political_status == ColonyData.STATUS_ANNEXED:
			colony_income_value *= 0.75

		colony_income += colony_income_value

	colony_income = max(
		colony_income,
		0.0
	)

	expansion_budget = (
		colony_income
		* 0.10
	)

	expansion_budget += (
		trade_income
		* 0.05
	)

	expansion_budget = clamp(
		expansion_budget,
		0.0,
		100.0
	)

	economy += (
		colony_income
		* 0.01
	)

	economy += (
		trade_income
		* 0.005
	)

	economy = clamp(
		economy,
		1.0,
		100.0
	)

func simulate_strategic_development() -> void:
	var available_development: float = (
		economy * 0.02
	)

	available_development += (
		colony_income * 0.01
	)

	available_development += (
		trade_income * 0.01
	)

	available_development = max(
		available_development,
		0.0
	)

	var science_factor: float = (
		science / 100.0
	)

	var militarism_factor: float = (
		militarism / 100.0
	)

	var expansion_factor: float = (
		expansionism / 100.0
	)

	var diplomacy_factor: float = (
		diplomacy / 100.0
	)

	technology += (
		available_development
		* (
			0.50
			+ science_factor * 0.50
		)
	)

	space_capability += (
		available_development
		* (
			0.20
			+ expansion_factor * 0.40
			+ science_factor * 0.20
		)
	)

	military_power += (
		available_development
		* (
			0.10
			+ militarism_factor * 0.60
		)
	)

	if diplomacy_factor > 0.70:
		military_power *= 0.998

	technology = clamp(
		technology,
		1.0,
		100.0
	)

	space_capability = clamp(
		space_capability,
		0.0,
		100.0
	)

	military_power = clamp(
		military_power,
		0.0,
		100.0
	)
