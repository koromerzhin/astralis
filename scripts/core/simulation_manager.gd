class_name SimulationManager
extends Node


signal year_changed(year: int)
signal event_logged(event_text: String, involves_player: bool)

const CIVILIZATION_SPATIAL_CELL_SIZE := 400.0
const RELATION_DISCOVERY_INTERVAL := 10
const PLANET_SPATIAL_CELL_SIZE := 400.0
const COLONIZATION_COOLDOWN := 5
const SYSTEM_SPATIAL_CELL_SIZE := 400.0

@export var years_per_second: float = 1.0
@export var simulation_running: bool = true


var current_year: int = 0
var player_civilization_id: int = -1
var _year_accumulator: float = 0.0
var _next_civilization_id: int = 0
var _next_civilization_global_id: int = 0
var _relation_discovery_year: int = -1
var _civilization_system_influence: Dictionary = {}
var _contested_systems: Dictionary = {}
var _system_generator := SystemGenerator.new()
var _colonizable_planets: Array[PlanetData] = []
var _systems: Dictionary = {}
var _relations: Dictionary = {}
var _civilizations: Dictionary = {}
var _civilization_interaction_ranges: Dictionary = {}
var _planets: Dictionary = {}
var _planet_system_ids: Dictionary = {}
var _system_planets: Dictionary = {}
var _system_positions: Dictionary = {}
var _civilization_system_ids: Dictionary = {}
var _civilization_allies: Dictionary = {}
var _colonizable_planet_system_ids: Dictionary = {}
var _civilization_positions: Dictionary = {}
var _civilization_spatial_grid: Dictionary = {}
var _colonizable_planet_spatial_grid: Dictionary = {}
var _civilization_next_colonization_year: Dictionary = {}
var _civilization_controlled_system_ids: Dictionary = {}
var _civilization_territorial_claims: Dictionary = {}
var _civilization_allies_dirty: bool = true
var _system_spatial_grid: Dictionary = {}
var _civilization_exploration_frontiers: Dictionary = {}
var _civilization_exploration_ranges: Dictionary = {}
var _civilization_system_closest_distances: Dictionary = {}
var _civilization_claim_distance_cache: Dictionary = {}
# =====================================================
# INITIALISATION
# =====================================================

func initialize(stars: Array[Dictionary]) -> void:
	_systems.clear()
	_relations.clear()
	_civilizations.clear()
	_civilization_interaction_ranges.clear()
	_planets.clear()
	_planet_system_ids.clear()
	_system_positions.clear()
	_civilization_system_ids.clear()
	_system_planets.clear()
	_colonizable_planets.clear()
	_colonizable_planet_system_ids.clear()
	_civilization_positions.clear()
	_civilization_spatial_grid.clear()
	_colonizable_planet_spatial_grid.clear()
	_civilization_next_colonization_year.clear()
	_civilization_controlled_system_ids.clear()
	_civilization_territorial_claims.clear()

	_civilization_allies.clear()
	_civilization_allies_dirty = true

	current_year = 0
	_year_accumulator = 0.0
	_relation_discovery_year = -1

	_next_civilization_id = 0
	_next_civilization_global_id = 1

	for star in stars:
		var star_id: int = star["id"]
		var system_seed: int = star["system_seed"]
		var star_type: String = star["type"]
		var position: Vector2 = star["position"]

		var system: Dictionary = (
			_system_generator.generate(
				system_seed,
				star_type,
				star_id
			)
		)

		system["id"] = star_id
		system["position"] = position

		_systems[star_id] = system

		_system_positions[
			star_id
		] = position

		var planets: Array[PlanetData] = (
			system.get(
				"planets",
				[]
			)
		)

		_system_planets[
			star_id
		] = planets

		for planet in planets:
			if planet == null:
				continue

			_planets[
				planet.global_id
			] = planet

			_planet_system_ids[
				planet.global_id
			] = star_id

			if (
				planet.type != "gas_giant"
				and planet.civilization == null
				and planet.colony_owner_id == -1
				and planet.habitability >= 30.0
			):
				_colonizable_planets.append(
					planet
				)

				_colonizable_planet_system_ids[
					planet.global_id
				] = star_id

			if planet.civilization == null:
				continue

			var civilization: CivilizationData = (
				planet.civilization
			)

			_civilizations[
				civilization.global_id
			] = civilization

			_civilization_system_ids[
				civilization.global_id
			] = star_id

			if not _civilization_controlled_system_ids.has(
				civilization.global_id
			):
				_civilization_controlled_system_ids[
					civilization.global_id
				] = []

			_civilization_controlled_system_ids[
				civilization.global_id
			].append(
				star_id
			)

			_civilization_positions[
				civilization.global_id
			] = position

			# Une civilisation connaît toujours son
			# propre système natal.
			civilization.explore_system(
				star_id
			)

	_build_civilization_spatial_grid()
	_build_colonizable_planet_spatial_grid()

	# Les relations diplomatiques ne sont pas créées
	# automatiquement au démarrage.
	_create_all_relations()

	for civilization in _civilizations.values():
		if civilization == null:
			continue

		_next_civilization_id = max(
			_next_civilization_id,
			civilization.id + 1
		)

		_next_civilization_global_id = max(
			_next_civilization_global_id,
			civilization.global_id + 1
		)

	_reconcile_home_colonies()

# =====================================================
# BOUCLE DE SIMULATION
# =====================================================

func _process(delta: float) -> void:
	if not simulation_running:
		return

	_year_accumulator += (
		delta * years_per_second
	)

	while _year_accumulator >= 1.0:
		_year_accumulator -= 1.0
		_advance_year()


func _advance_year() -> void:
	current_year += 1

	_reset_trade_income()

	var start_total := Time.get_ticks_usec()

	var start_systems := Time.get_ticks_usec()
	_simulate_all_systems()
	var end_systems := Time.get_ticks_usec()

	var start_colonization := Time.get_ticks_usec()
	_try_dynamic_colonization()
	var end_colonization := Time.get_ticks_usec()

	var start_exploration := Time.get_ticks_usec()
	_simulate_exploration()
	var end_exploration := Time.get_ticks_usec()

	var start_rebellions := Time.get_ticks_usec()
	_simulate_colony_rebellions()
	var end_rebellions := Time.get_ticks_usec()

	var start_dynamic_relations := Time.get_ticks_usec()

	var territorial_tensions_start := Time.get_ticks_usec()

	if (
		_relation_discovery_year < 0
		or current_year >= _relation_discovery_year
	):
		_update_dynamic_relations()

		_relation_discovery_year = (
			current_year
			+ RELATION_DISCOVERY_INTERVAL
		)

		_evaluate_territorial_tensions()

	var territorial_tensions_end := Time.get_ticks_usec()

	var territorial_claim_conflicts_start := Time.get_ticks_usec()

	if (
		_relation_discovery_year == current_year
	):
		_evaluate_territorial_claim_conflicts()

	var territorial_claim_conflicts_end := Time.get_ticks_usec()

	var territorial_demands_start := Time.get_ticks_usec()

	if (
		_relation_discovery_year == current_year
	):
		_evaluate_territorial_demands()

	var territorial_demands_end := Time.get_ticks_usec()

	var territorial_process_start := Time.get_ticks_usec()

	if (
		_relation_discovery_year == current_year
	):
		_process_territorial_demands()

	var territorial_process_end := Time.get_ticks_usec()

	var end_dynamic_relations := Time.get_ticks_usec()

	var start_relations := Time.get_ticks_usec()

	var t0 := Time.get_ticks_usec()
	_simulate_all_relations()
	var t1 := Time.get_ticks_usec()

	_update_controlled_territories()
	var t2 := Time.get_ticks_usec()

	_update_territorial_claims()
	var t3 := Time.get_ticks_usec()

	_update_civilization_system_influence()
	var t4 := Time.get_ticks_usec()

	_evaluate_contested_system_tensions()
	var t5 := Time.get_ticks_usec()

	_evaluate_peaceful_integrations()
	var t6 := Time.get_ticks_usec()

	var end_relations := Time.get_ticks_usec()

	var start_trade := Time.get_ticks_usec()

	_evaluate_trade_decisions()
	_evaluate_economic_sanctions()
	_evaluate_trade_recovery()
	_apply_economic_dependence_effects()
	_update_trade_networks()
	_apply_trade_network_effects()
	_evaluate_trade_network_alliances()

	var end_trade := Time.get_ticks_usec()

	var start_war_decisions := Time.get_ticks_usec()

	_evaluate_war_decisions()
	_evaluate_allied_interventions()

	var end_war_decisions := Time.get_ticks_usec()

	var start_allies := Time.get_ticks_usec()
	_call_allies_to_war()
	var end_allies := Time.get_ticks_usec()

	var start_revenge := Time.get_ticks_usec()
	_update_war_revenge()
	var end_revenge := Time.get_ticks_usec()

	var start_cleanup := Time.get_ticks_usec()
	_cleanup_finished_wars()
	var end_cleanup := Time.get_ticks_usec()

	var start_alliances := Time.get_ticks_usec()
	_update_alliances()

	if _civilization_allies_dirty:
		_rebuild_civilization_allies()
		_civilization_allies_dirty = false

	var end_alliances := Time.get_ticks_usec()

	var end_total := Time.get_ticks_usec()

	print(
		"ANNÉE ",
		current_year,
		" | Total: ",
		(end_total - start_total) / 1000.0,
		" ms",
		" | Systèmes: ",
		(end_systems - start_systems) / 1000.0,
		" ms",
		" | Colonisation: ",
		(end_colonization - start_colonization) / 1000.0,
		" ms",
		" | Exploration: ",
		(end_exploration - start_exploration) / 1000.0,
		" ms",
		" | Révoltes: ",
		(end_rebellions - start_rebellions) / 1000.0,
		" ms",
		" | Relations dynamiques: ",
		(end_dynamic_relations - start_dynamic_relations) / 1000.0,
		" ms",
		" |   tensions: ",
		(territorial_tensions_end - territorial_tensions_start) / 1000.0,
		" ms",
		" |   conflits territoriaux: ",
		(territorial_claim_conflicts_end - territorial_claim_conflicts_start) / 1000.0,
		" ms",
		" |   demandes territoriales: ",
		(territorial_demands_end - territorial_demands_start) / 1000.0,
		" ms",
		" |   traitement demandes: ",
		(territorial_process_end - territorial_process_start) / 1000.0,
		" ms",
		" | Relations: ",
		(end_relations - start_relations) / 1000.0,
		" ms",
		" |   simulation: ",
		(t1 - t0) / 1000.0,
		" ms",
		" |   territoires: ",
		(t2 - t1) / 1000.0,
		" ms",
		" |   claims: ",
		(t3 - t2) / 1000.0,
		" ms",
		" |   influence: ",
		(t4 - t3) / 1000.0,
		" ms",
		" |   contested: ",
		(t5 - t4) / 1000.0,
		" ms",
		" |   integrations: ",
		(t6 - t5) / 1000.0,
		" ms",
		" | Commerce: ",
		(end_trade - start_trade) / 1000.0,
		" ms",
		" | Guerres: ",
		(end_war_decisions - start_war_decisions) / 1000.0,
		" ms",
		" | Alliés: ",
		(end_allies - start_allies) / 1000.0,
		" ms",
		" | Revanche: ",
		(end_revenge - start_revenge) / 1000.0,
		" ms",
		" | Nettoyage: ",
		(end_cleanup - start_cleanup) / 1000.0,
		" ms",
		" | Alliances: ",
		(end_alliances - start_alliances) / 1000.0,
		" ms"
	)

	year_changed.emit(current_year)

# =====================================================
# SYSTÈMES
# =====================================================

func _simulate_all_systems() -> void:
	for system in _systems.values():
		_simulate_system(system)

func _simulate_system(
	system: Dictionary
) -> void:
	if system.is_empty():
		return

	var planets: Array[PlanetData] = system.get(
		"planets",
		[]
	)

	if planets.is_empty():
		return

	for planet in planets:
		if planet == null:
			continue

		if planet.civilization == null:
			continue

		var civilization: CivilizationData = (
			planet.civilization
		)

		civilization.simulate_year(
			planet.habitability,
			planet.population_capacity
		)

		planet.population = civilization.population

		if planet.colony != null:
			planet.colony.population = (
				civilization.population
			)

		civilization.simulate_economy_and_technology(
			planet.habitability,
			planet.minerals,
			planet.energy,
			planet.biological_resources
		)

		civilization.apply_primary_goal()

		civilization.simulate_colonies()

		civilization.simulate_colony_economy()

		civilization.simulate_strategic_development()

		for colony in civilization.colonies:
			if colony == null:
				continue

			var colony_planet: PlanetData = (
				_planets.get(
					colony.planet_id,
					null
				)
			)

			if colony_planet == null:
				continue

			colony_planet.population = (
				colony.population
			)

# =====================================================
# CIVILISATIONS D'UN SYSTÈME
# =====================================================

func _get_system_civilizations(
	system: Dictionary
) -> Array[CivilizationData]:
	var civilizations: Array[CivilizationData] = []

	if system.is_empty():
		return civilizations

	var system_id: int = system.get(
		"id",
		-1
	)

	var planets: Array[PlanetData] = system.get(
		"planets",
		[]
	)

	# -------------------------------------------------
	# CIVILISATIONS-MÈRES DU SYSTÈME
	# -------------------------------------------------

	for planet in planets:
		if planet == null:
			continue

		if planet.civilization == null:
			continue

		var civilization: CivilizationData = (
			planet.civilization
		)

		if not civilizations.has(
			civilization
		):
			civilizations.append(
				civilization
			)

	# -------------------------------------------------
	# CIVILISATIONS POSSÉDANT UNE COLONIE
	# DANS CE SYSTÈME
	# -------------------------------------------------

	for other_system in _systems.values():
		var other_planets: Array[PlanetData] = (
			other_system.get(
				"planets",
				[]
			)
		)

		for other_planet in other_planets:
			if other_planet == null:
				continue

			if other_planet.civilization == null:
				continue

			var owner: CivilizationData = (
				other_planet.civilization
			)

			for colony in owner.colonies:
				if colony == null:
					continue

				var colony_planet: PlanetData = (
					_find_planet_by_global_id(
						colony.planet_id
					)
				)

				if colony_planet == null:
					continue

				var colony_system: Dictionary = (
					_find_system_containing_planet(
						colony_planet.global_id
					)
				)

				if colony_system.is_empty():
					continue

				if colony_system.get("id", -1) != system_id:
					continue

				if not civilizations.has(owner):
					civilizations.append(owner)

	return civilizations


# =====================================================
# RELATIONS
# =====================================================

func _create_all_relations() -> void:
	# Les civilisations commencent sans relations
	# diplomatiques entre elles.
	#
	# Les relations seront créées uniquement lorsqu'une
	# civilisation découvre une autre civilisation
	# par exploration.
	_relations.clear()

func _update_dynamic_relations() -> void:
	# Les relations diplomatiques ne sont plus créées
	# automatiquement par la proximité spatiale.
	#
	# Une civilisation doit d'abord découvrir un système
	# par exploration pour établir un premier contact.
	return

func _get_relation_key(
	civilization_a_id: int,
	civilization_b_id: int
) -> String:

	if civilization_a_id == civilization_b_id:
		return ""

	var first_id: int = min(
		civilization_a_id,
		civilization_b_id
	)

	var second_id: int = max(
		civilization_a_id,
		civilization_b_id
	)

	return (
		str(first_id)
		+ "_"
		+ str(second_id)
	)


func _create_relation(
	civilization_a: CivilizationData,
	civilization_b: CivilizationData
) -> RelationData:

	if civilization_a == null:
		return null

	if civilization_b == null:
		return null

	if civilization_a.global_id == civilization_b.global_id:
		return null

	var relation_key: String = _get_relation_key(
		civilization_a.global_id,
		civilization_b.global_id
	)

	if relation_key.is_empty():
		return null

	if _relations.has(relation_key):
		return _relations[relation_key]

	var relation := RelationData.new()

	relation.civilization_a_id = (
		civilization_a.global_id
	)

	relation.civilization_b_id = (
		civilization_b.global_id
	)

	var system_id_a = (
		_civilization_system_ids.get(
			civilization_a.global_id,
			null
		)
	)

	var system_id_b = (
		_civilization_system_ids.get(
			civilization_b.global_id,
			null
		)
	)

	if system_id_a != null \
	and system_id_b != null:

		var position_a: Vector2 = (
			_system_positions.get(
				system_id_a,
				Vector2.ZERO
			)
		)

		var position_b: Vector2 = (
			_system_positions.get(
				system_id_b,
				Vector2.ZERO
			)
		)

		relation.distance = (
			position_a.distance_to(position_b)
		)

	_relations[relation_key] = relation

	print(
		"[Diplomatie] Nouvelle relation entre ",
		civilization_a.name,
		" (#",
		civilization_a.global_id,
		") et ",
		civilization_b.name,
		" (#",
		civilization_b.global_id,
		")"
	)

	return relation

func _get_relation(
	civilization_a_id: int,
	civilization_b_id: int
) -> RelationData:
	var key: String = (
		_get_relation_key(
			civilization_a_id,
			civilization_b_id
		)
	)

	if not _relations.has(key):
		return null

	return _relations[key]


# =====================================================
# SIMULATION DES RELATIONS
# =====================================================

func _simulate_all_relations() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		if relation.at_war:
			var coalition_power_a: float = (
				_calculate_war_coalition_power(
					civilization_a,
					civilization_b
				)
			)

			var coalition_power_b: float = (
				_calculate_war_coalition_power(
					civilization_b,
					civilization_a
				)
			)

			_apply_war_damage(
				civilization_a,
				civilization_b,
				relation
			)

			var war_result: String = (
				relation.simulate_war_year(
					current_year,
					coalition_power_a,
					coalition_power_b
				)
			)

			if not war_result.is_empty():
				_log_event(
					"[Guerre] " + war_result,
					[
						civilization_a.global_id,
						civilization_b.global_id,
					]
				)

				if relation.last_war_winner == (
					civilization_a.global_id
				):
					_capture_colony(
						civilization_a,
						civilization_b
					)

				elif relation.last_war_winner == (
					civilization_b.global_id
				):
					_capture_colony(
						civilization_b,
						civilization_a
					)

			continue

		relation.simulate_year(
			civilization_a.economy,
			civilization_a.technology,
			civilization_b.economy,
			civilization_b.technology,
			civilization_a,
			civilization_b
		)

		relation.simulate_economic_dependence(
			civilization_a,
			civilization_b
		)

# =====================================================
# COMMERCE
# =====================================================

func _reset_trade_income() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	for civilization in civilizations:
		if civilization == null:
			continue

		civilization.reset_trade_income()


func _calculate_trade_value(
	relation: RelationData,
	civilization_a: CivilizationData,
	civilization_b: CivilizationData
) -> float:
	if relation == null:
		return 0.0

	if civilization_a == null:
		return 0.0

	if civilization_b == null:
		return 0.0

	if relation.at_war:
		return 0.0

	if relation.relation < -20.0:
		return 0.0

	var economic_power: float = (
		civilization_a.economy
		+ civilization_b.economy
	) * 0.5

	var technology_factor: float = (
		civilization_a.technology
		+ civilization_b.technology
	) * 0.01

	var relation_factor: float = clamp(
		(relation.relation + 100.0) / 200.0,
		0.0,
		1.0
	)

	var trade_value: float = (
		economic_power
		* technology_factor
		* relation_factor
		* 0.10
	)

	return max(
		trade_value,
		0.0
	)


# =====================================================
# GUERRE
# =====================================================

func _try_start_war(
	relation: RelationData,
	civilization_a: CivilizationData,
	civilization_b: CivilizationData
) -> void:
	if relation == null:
		return

	if civilization_a == null:
		return

	if civilization_b == null:
		return

	if relation.at_war:
		return

	if relation.relation > -60.0:
		return

	if relation.trust > 35.0:
		return

	var power_a: float = (
		civilization_a.military_power
	)

	var power_b: float = (
		civilization_b.military_power
	)

	var total_power: float = (
		power_a
		+ power_b
	)

	if total_power <= 0.0:
		return

	var power_ratio_a: float = (
		power_a
		/ total_power
	)

	var probability: float = 0.01

	if relation.relation <= -80.0:
		probability += 0.05

	elif relation.relation <= -70.0:
		probability += 0.03

	if relation.trust <= 20.0:
		probability += 0.03

	if power_ratio_a >= 0.70:
		probability += 0.03

	elif power_ratio_a >= 0.60:
		probability += 0.01

	if power_a < 20.0:
		probability *= 0.25

	elif power_a < 30.0:
		probability *= 0.50

	if power_a >= 70.0:
		probability += 0.02

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		civilization_a.seed
		+ civilization_b.seed * 3
		+ current_year * 997
	)

	if rng.randf() > probability:
		return

	var message: String = (
		relation.start_war(
			current_year
		)
	)

	if message != "":
		_log_event(
			"[Guerre] "
			+ civilization_a.name
			+ " déclare la guerre à "
			+ civilization_b.name,
			[
				civilization_a.global_id,
				civilization_b.global_id,
			]
		)


func _try_revenge_war(
	relation: RelationData,
	civilization_a: CivilizationData,
	civilization_b: CivilizationData
) -> void:
	if relation == null:
		return

	if civilization_a == null:
		return

	if civilization_b == null:
		return

	if relation.at_war:
		return

	if relation.revenge_a <= 0.0:
		return

	if relation.revenge_a < 50.0:
		return

	if civilization_a.military_power < 30.0:
		return

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		civilization_a.seed
		+ civilization_b.seed
		+ current_year * 131
	)

	var revenge_probability: float = (
		0.01
		+ relation.revenge_a * 0.0005
	)

	if civilization_a.military_power >= 60.0:
		revenge_probability += 0.02

	if civilization_a.technology >= 60.0:
		revenge_probability += 0.01

	if rng.randf() > revenge_probability:
		return

	var message: String = (
		relation.start_war(
			current_year
		)
	)

	if message != "":
		_log_event(
			"[Revanche] "
			+ civilization_a.name
			+ " déclenche une guerre de revanche contre "
			+ civilization_b.name,
			[
				civilization_a.global_id,
				civilization_b.global_id,
			]
		)


func _calculate_war_bloc_power(
	civilization: CivilizationData,
	enemy: CivilizationData
) -> float:
	if civilization == null:
		return 0.0

	if enemy == null:
		return 0.0

	var total_power: float = (
		civilization.military_power
	)

	var members: Array[CivilizationData] = (
		_get_war_bloc_members(
			civilization
		)
	)

	for member in members:
		if member == null:
			continue

		if member.global_id == civilization.global_id:
			continue

		if member.global_id == enemy.global_id:
			continue

		total_power += (
			member.military_power
		)

	return total_power


func _get_war_bloc_members(
	civilization: CivilizationData
) -> Array[CivilizationData]:
	var members: Array[CivilizationData] = []

	if civilization == null:
		return members

	members.append(
		civilization
	)

	for relation in _relations.values():
		if relation == null:
			continue

		if not relation.at_war:
			continue

		if not relation.alliance:
			continue

		var ally_id: int = -1

		if (
			relation.civilization_a_id
			== civilization.global_id
		):
			ally_id = relation.civilization_b_id

		elif (
			relation.civilization_b_id
			== civilization.global_id
		):
			ally_id = relation.civilization_a_id

		if ally_id == -1:
			continue

		var ally: CivilizationData = (
			_find_civilization(
				ally_id
			)
		)

		if ally == null:
			continue

		if members.has(ally):
			continue

		var enemy_ids: Array[int] = (
			_get_war_enemy_ids(
				civilization
			)
		)

		if enemy_ids.has(
			ally.global_id
		):
			continue

		members.append(
			ally
		)

	return members


func _get_war_enemy_ids(
	civilization: CivilizationData
) -> Array[int]:
	var enemy_ids: Array[int] = []

	if civilization == null:
		return enemy_ids

	for relation in _relations.values():
		if relation == null:
			continue

		if not relation.at_war:
			continue

		var other_id: int = -1

		if (
			relation.civilization_a_id
			== civilization.global_id
		):
			other_id = relation.civilization_b_id

		elif (
			relation.civilization_b_id
			== civilization.global_id
		):
			other_id = relation.civilization_a_id

		if other_id == -1:
			continue

		if enemy_ids.has(other_id):
			continue

		enemy_ids.append(
			other_id
		)

	return enemy_ids


func _apply_war_bloc_losses(
	members: Array[CivilizationData],
	total_losses: float
) -> void:
	if members.is_empty():
		return

	var loss_per_member: float = (
		total_losses
		/ float(members.size())
	)

	for civilization in members:
		if civilization == null:
			continue

		civilization.apply_war_effect()

		civilization.apply_military_losses(
			loss_per_member
		)


# =====================================================
# ALLIANCES ET GUERRES
# =====================================================

func _call_allies_to_war() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if not relation.at_war:
			continue

		var attacker_id: int = (
			relation.civilization_a_id
		)

		var defender_id: int = (
			relation.civilization_b_id
		)

		var attacker: CivilizationData = (
			get_civilization(
				attacker_id
			)
		)

		var defender: CivilizationData = (
			get_civilization(
				defender_id
			)
		)

		if attacker == null:
			continue

		if defender == null:
			continue

		_call_allies_for_civilization(
			defender,
			attacker
		)

		_call_allies_for_civilization(
			attacker,
			defender
		)

func _call_allies_for_civilization(
	civilization: CivilizationData,
	enemy: CivilizationData
) -> void:
	if civilization == null:
		return

	if enemy == null:
		return

	var civilization_id: int = (
		civilization.global_id
	)

	var enemy_id: int = (
		enemy.global_id
	)

	var ally_ids: Array = (
		_civilization_allies.get(
			civilization_id,
			[]
		)
	)

	if ally_ids.is_empty():
		return

	for ally_id in ally_ids:
		var ally: CivilizationData = (
			_civilizations.get(
				ally_id,
				null
			)
		)

		if ally == null:
			continue

		if ally.global_id == enemy_id:
			continue

		var ally_enemy_key: String = (
			_get_relation_key(
				ally_id,
				enemy_id
			)
		)

		if ally_enemy_key.is_empty():
			continue

		var ally_enemy_relation: RelationData = (
			_relations.get(
				ally_enemy_key,
				null
			)
		)

		if ally_enemy_relation == null:
			continue

		if ally_enemy_relation.at_war:
			continue

		ally_enemy_relation.join_war(
			current_year
		)

		ally_enemy_relation.relation = -80.0
		ally_enemy_relation.trust = 10.0

		print(
			"[Alliance] ",
			ally.name,
			" rejoint la guerre de ",
			civilization.name,
			" contre ",
			enemy.name
		)

func _update_alliances() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		if not civilization_a.knows_civilization(
			civilization_b.global_id
		):
			continue

		if not civilization_b.knows_civilization(
			civilization_a.global_id
		):
			continue

		if relation.at_war:
			if relation.alliance:
				relation.alliance = false
				_civilization_allies_dirty = true

				print(
					"[Alliance] ",
					civilization_a.name,
					" et ",
					civilization_b.name,
					" rompent leur alliance à cause de la guerre."
				)

			continue

		if not relation.alliance:
			var wants_a: bool = (
				civilization_a.wants_to_form_alliance(
					civilization_b
				)
			)

			var wants_b: bool = (
				civilization_b.wants_to_form_alliance(
					civilization_a
				)
			)

			if not wants_a or not wants_b:
				continue

			if not relation.can_form_alliance():
				continue

			relation.alliance = true
			_civilization_allies_dirty = true

			_log_event(
				"[Alliance] "
				+ civilization_a.name
				+ " et "
				+ civilization_b.name
				+ " deviennent alliés.",
				[
					civilization_a.global_id,
					civilization_b.global_id,
				]
			)

		else:
			var wants_a: bool = (
				civilization_a.wants_to_form_alliance(
					civilization_b
				)
			)

			var wants_b: bool = (
				civilization_b.wants_to_form_alliance(
					civilization_a
				)
			)

			if not wants_a and not wants_b:
				relation.alliance = false
				_civilization_allies_dirty = true

				_log_event(
					"[Alliance] "
					+ civilization_a.name
					+ " et "
					+ civilization_b.name
					+ " rompent leur alliance.",
					[
						civilization_a.global_id,
						civilization_b.global_id,
					]
				)

				continue

			if relation.can_break_alliance():
				relation.alliance = false
				_civilization_allies_dirty = true

				_log_event(
					"[Alliance] "
					+ civilization_a.name
					+ " et "
					+ civilization_b.name
					+ " rompent leur alliance.",
					[
						civilization_a.global_id,
						civilization_b.global_id,
					]
				)

# =====================================================
# CONQUÊTES
# =====================================================

func _try_bloc_conquest(
	relation: RelationData,
	winner: CivilizationData,
	defeated: CivilizationData
) -> String:
	if relation == null:
		return ""

	if winner == null:
		return ""

	if defeated == null:
		return ""

	var bloc_members: Array[CivilizationData] = (
		_get_war_bloc_members(
			winner
		)
	)

	if bloc_members.is_empty():
		return ""

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		winner.seed
		+ defeated.seed * 31
		+ current_year * 997
	)

	var conqueror: CivilizationData = (
		bloc_members[
			rng.randi_range(
				0,
				bloc_members.size() - 1
			)
		]
	)

	if conqueror == null:
		return ""

	return _try_conquer_colony(
		relation,
		conqueror,
		defeated
	)


func _try_conquer_colony(
	relation: RelationData,
	winner: CivilizationData,
	defeated: CivilizationData
) -> String:
	if relation == null:
		return ""

	if winner == null:
		return ""

	if defeated == null:
		return ""

	var target_colony: ColonyData = null
	var target_planet: PlanetData = null

	var weakest_stability: float = INF

	for colony in defeated.colonies:
		if colony == null:
			continue

		var planet: PlanetData = (
			_find_planet_by_global_id(
				colony.planet_id
			)
		)

		if planet == null:
			continue

		if colony.stability < weakest_stability:
			weakest_stability = colony.stability
			target_colony = colony
			target_planet = planet

	if target_colony == null:
		return ""

	if target_planet == null:
		return ""

	var winner_power: float = (
		winner.military_power
	)

	var defeated_power: float = (
		defeated.military_power
	)

	var total_power: float = (
		winner_power
		+ defeated_power
	)

	if total_power <= 0.0:
		return ""

	var power_ratio: float = (
		winner_power
		/ total_power
	)

	var probability: float = 0.10

	if power_ratio >= 0.80:
		probability += 0.35

	elif power_ratio >= 0.70:
		probability += 0.25

	elif power_ratio >= 0.60:
		probability += 0.15

	if target_colony.stability < 30.0:
		probability += 0.20

	elif target_colony.stability < 50.0:
		probability += 0.10

	if target_colony.development < 20.0:
		probability += 0.10

	elif target_colony.development < 40.0:
		probability += 0.05

	if winner.technology >= 70.0:
		probability += 0.10

	probability = clamp(
		probability,
		0.0,
		0.90
	)

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		winner.seed
		+ defeated.seed * 3
		+ target_planet.global_id * 17
		+ current_year * 997
	)

	if rng.randf() > probability:
		return ""

	var conquered_colony: ColonyData = (
		defeated.remove_colony(
			target_colony.planet_id
		)
	)

	if conquered_colony == null:
		return ""

	conquered_colony.occupy()

	winner.take_over_colony(
		conquered_colony
	)

	target_planet.colony_owner_id = (
		winner.global_id
	)

	target_planet.population = (
		conquered_colony.population
	)

	target_planet.population_capacity = (
		conquered_colony.population_capacity
	)

	return (
		winner.name
		+ " conquiert la colonie sur la planète #"
		+ str(target_planet.global_id)
		+ " de "
		+ defeated.name
	)


# =====================================================
# COLONISATION
# =====================================================

func register_planet_control(
	civilization_id: int,
	planet_id: int,
	system_id: int
) -> void:
	_colonizable_planets.erase(
		_planets.get(planet_id, null)
	)

	_colonizable_planet_system_ids.erase(
		planet_id
	)

	if not _civilization_controlled_system_ids.has(
		civilization_id
	):
		_civilization_controlled_system_ids[
			civilization_id
		] = []

	var controlled: Array = (
		_civilization_controlled_system_ids[
			civilization_id
		]
	)

	if not controlled.has(
		system_id
	):
		controlled.append(
			system_id
		)


func _try_dynamic_colonization() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.is_empty():
		return

	_build_colonizable_planet_spatial_grid()

	for civilization in civilizations:
		if civilization == null:
			continue

		if civilization.economy < 20.0:
			continue

		if civilization.technology < 20.0:
			continue

		if civilization.expansion_budget < 1.0:
			continue

		var controlled_systems: Array = (
			_civilization_controlled_system_ids.get(
				civilization.global_id,
				[]
			)
		)

		if controlled_systems.is_empty():
			continue

		var interaction_range: float = (
			civilization.get_interaction_range()
		)

		if interaction_range <= 0.0:
			continue

		var controlled_positions: Array[Vector2] = []

		for controlled_system_value in controlled_systems:
			var controlled_system_id: int = (
				int(controlled_system_value)
			)

			var controlled_position: Vector2 = (
				_system_positions.get(
					controlled_system_id,
					Vector2.INF
				)
			)

			if controlled_position != Vector2.INF:
				controlled_positions.append(
					controlled_position
				)

		if controlled_positions.is_empty():
			continue

		var interaction_range_squared: float = (
			interaction_range
			* interaction_range
		)

		var cell_radius: int = ceili(
			interaction_range
			/ PLANET_SPATIAL_CELL_SIZE
		)

		var candidate_ids: Dictionary = {}

		for controlled_position in controlled_positions:
			var center_x: int = floori(
				controlled_position.x
				/ PLANET_SPATIAL_CELL_SIZE
			)

			var center_y: int = floori(
				controlled_position.y
				/ PLANET_SPATIAL_CELL_SIZE
			)

			for offset_x in range(
				-cell_radius,
				cell_radius + 1
			):
				for offset_y in range(
					-cell_radius,
					cell_radius + 1
				):
					var cell_key: Vector2i = Vector2i(
						center_x + offset_x,
						center_y + offset_y
					)

					var planets_in_cell: Array = (
						_colonizable_planet_spatial_grid.get(
							cell_key,
							[]
						)
					)

					for planet_id_value in planets_in_cell:
						candidate_ids[
							planet_id_value
						] = true

		var candidate_infos: Array = []

		for planet_id_value in candidate_ids.keys():
			var planet_id: int = int(
				planet_id_value
			)

			var planet: PlanetData = _planets.get(
				planet_id,
				null
			)

			if planet == null:
				continue

			if planet.civilization != null:
				continue

			if planet.colony_owner_id != -1:
				continue

			if planet.habitability < 30.0:
				continue

			var planet_system_value = (
				_colonizable_planet_system_ids.get(
					planet.global_id,
					null
				)
			)

			if planet_system_value == null:
				continue

			var target_system_id: int = (
				int(planet_system_value)
			)

			var target_position: Vector2 = (
				_system_positions.get(
					target_system_id,
					Vector2.INF
				)
			)

			if target_position == Vector2.INF:
				continue

			var closest_distance_squared: float = INF

			for controlled_position in controlled_positions:
				var distance_squared: float = (
					controlled_position.distance_squared_to(
						target_position
					)
				)

				if distance_squared < (
					closest_distance_squared
				):
					closest_distance_squared = (
						distance_squared
					)

			if closest_distance_squared > (
				interaction_range_squared
			):
				continue

			# Une civilisation ne colonise pas son propre système.
			var system_owner: CivilizationData = (
				_find_civilization_in_system(
					target_system_id
				)
			)

			if system_owner == civilization:
				continue

			var closest_distance: float = sqrt(
				closest_distance_squared
			)

			var pressure: float = (
				1.0
				- closest_distance
				/ interaction_range
			)

			pressure = clamp(
				pressure,
				0.0,
				1.0
			)

			candidate_infos.append(
				{
					"planet": planet,
					"pressure": pressure * 100.0
				}
			)

		if candidate_infos.is_empty():
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = (
			civilization.seed
			+ current_year * 31337
			+ civilization.colony_planet_ids.size() * 7919
		)

		var best_score: float = -INF
		var best_planet: PlanetData = null

		for candidate_info in candidate_infos:
			var candidate: PlanetData = (
				candidate_info["planet"]
			)

			var territorial_pressure: float = (
				candidate_info["pressure"]
			)

			var habitability_score: float = (
				candidate.habitability
			)

			var random_factor: float = (
				rng.randf_range(
					0.0,
					10.0
				)
			)

			var score: float = (
				territorial_pressure * 0.60
				+ habitability_score * 0.30
				+ random_factor * 0.10
			)

			if score <= best_score:
				continue

			best_score = score
			best_planet = candidate

		var planet: PlanetData = best_planet

		if planet == null:
			continue

		var system_id_value = (
			_colonizable_planet_system_ids.get(
				planet.global_id,
				null
			)
		)

		if system_id_value == null:
			continue

		var target_system_id: int = (
			int(system_id_value)
		)

		if planet.civilization != null:
			continue

		if planet.colony_owner_id != -1:
			continue

		var colony_seed: int = (
			rng.randi()
		)

		civilization.add_colony(
			colony_seed,
			planet
		)

		planet.colony_owner_id = (
			civilization.global_id
		)
		
		civilization.expansion_budget = max(
			civilization.expansion_budget - 1.0,
			0.0
		)

		civilization.explore_system(
			target_system_id
		)

		if not _civilization_controlled_system_ids.has(
			civilization.global_id
		):
			_civilization_controlled_system_ids[
				civilization.global_id
			] = []

		var controlled_systems_after: Array = (
			_civilization_controlled_system_ids[
				civilization.global_id
			]
		)

		if not controlled_systems_after.has(
			target_system_id
		):
			controlled_systems_after.append(
				target_system_id
			)

		_log_event(
			"[Colonisation] "
			+ civilization.name
			+ " colonise la planète #"
			+ str(planet.global_id)
			+ " dans le système #"
			+ str(target_system_id),
			[civilization.global_id]
		)

		_colonizable_planets.erase(
			planet
		)

		_colonizable_planet_system_ids.erase(
			planet.global_id
		)

		# Une seule colonisation par civilisation et par année.
		continue

# =====================================================
# RÉBELLIONS
# =====================================================

func _simulate_colony_rebellions() -> void:
	var total_colonies: int = 0
	var processed_count: int = 0

	for civilization in _civilizations.values():
		if civilization == null:
			continue

		for colony in civilization.colonies:
			if colony == null:
				continue

			total_colonies += 1
			processed_count += 1

			var rebellion_chance: float = (
				100.0 - colony.stability
			)

			if rebellion_chance <= 0.0:
				continue

			if colony.stability < 10.0:
				rebellion_chance = 1.0
			else:
				rebellion_chance *= 0.00008

			var rng := RandomNumberGenerator.new()
			rng.seed = (
				colony.seed
				+ current_year * 997
			)

			if rng.randf() > rebellion_chance:
				continue

			var target_planet: PlanetData = (
				_planets.get(
					colony.planet_id,
					null
				)
			)

			if target_planet == null:
				continue

			colony.stability = max(
				colony.stability - 20.0,
				0.0
			)

			colony.development = max(
				colony.development - 10.0,
				0.0
			)

			colony.production = max(
				colony.production - 10.0,
				0.0
			)

			var new_civilization_id: int = (
				_find_next_civilization_id()
			)

			var new_civilization_seed: int = (
				colony.seed
				+ current_year * 1009
				+ new_civilization_id * 7919
			)

			var new_civilization := (
				CivilizationData.new()
			)

			new_civilization.initialize_from_rebellion(
				new_civilization_id,
				new_civilization_seed,
				target_planet,
				colony,
				civilization
			)

			new_civilization.global_id = (
				_generate_civilization_global_id()
			)

			_civilizations[
				new_civilization.global_id
			] = new_civilization

			var system_id = (
				_planet_system_ids.get(
					target_planet.global_id,
					null
				)
			)

			if system_id != null:
				_civilization_system_ids[
					new_civilization.global_id
				] = system_id
				
				_civilization_positions[
					new_civilization.global_id
				] = _system_positions.get(
					system_id,
					Vector2.ZERO
				)

				# La nouvelle civilisation reste active
				# et peut étendre sa sphère d'influence.
				_civilization_controlled_system_ids[
					new_civilization.global_id
				] = [system_id]

			civilization.remove_colony(
				colony.planet_id
			)

			target_planet.civilization = (
				new_civilization
			)

			target_planet.colony_owner_id = -1
			target_planet.colony = null

			target_planet.population = (
				new_civilization.population
			)

			new_civilization.attach_home_colony(
				target_planet
			)

			var relation: RelationData = (
				_create_relation(
					civilization,
					new_civilization
				)
			)

			if relation != null:
				relation.relation = -80.0
				relation.trust = 10.0
				relation.at_war = false
				relation.alliance = false

				relation.event_history.append(
					"Année "
					+ str(current_year)
					+ " : rébellion sur la planète #"
					+ str(target_planet.global_id)
					+ "."
				)

				if relation.event_history.size() > 20:
					relation.event_history.pop_front()

			print(
				"RÉBELLION : civilisation #",
				civilization.global_id,
				" -> nouvelle civilisation #",
				new_civilization.global_id,
				" sur planète #",
				target_planet.global_id
			)

	if current_year == 1:
		print(
			"DIAGNOSTIC RÉVOLTES : ",
			total_colonies,
			" colonies trouvées, ",
			processed_count,
			" colonies traitées."
		)

func _trigger_colony_rebellion(
	former_civilization: CivilizationData,
	colony: ColonyData,
	target_planet: PlanetData
) -> void:
	if former_civilization == null:
		return

	if colony == null:
		return

	if target_planet == null:
		return

	var rebellion_seed: int = (
		colony.seed
		+ current_year * 1009
		+ target_planet.global_id * 31
	)

	var rebellion_id: int = (
		_find_next_civilization_id()
	)

	var rebellion_global_id: int = (
		_generate_civilization_global_id()
	)

	var rebel_civilization := CivilizationData.new()

	rebel_civilization.initialize_from_rebellion(
		rebellion_id,
		rebellion_seed,
		target_planet,
		colony,
		former_civilization
	)

	rebel_civilization.global_id = (
		rebellion_global_id
	)

	former_civilization.remove_colony(
		colony.planet_id
	)

	target_planet.civilization = (
		rebel_civilization
	)

	target_planet.colony_owner_id = -1
	target_planet.colony = null

	target_planet.population = (
		rebel_civilization.population
	)

	rebel_civilization.attach_home_colony(
		target_planet
	)

	var relation: RelationData = (
		_get_relation(
			rebel_civilization.global_id,
			former_civilization.global_id
		)
	)

	if relation == null:
		relation = _create_relation(
			rebel_civilization,
			former_civilization
		)

	if relation != null:
		relation.relation = -90.0
		relation.trust = 5.0

	_log_event(
		"[Rébellion] "
		+ rebel_civilization.name
		+ " devient indépendante sur la planète #"
		+ str(target_planet.global_id),
		[
			rebel_civilization.global_id,
			former_civilization.global_id,
		]
	)


# =====================================================
# MÉMOIRE DES GUERRES
# =====================================================

func _update_war_revenge() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			continue

		if relation.war_ended_year < 0:
			continue

		var revenge_decay: float = 0.5

		if relation.revenge_a > 0.0:
			relation.revenge_a -= revenge_decay

		if relation.revenge_b > 0.0:
			relation.revenge_b -= revenge_decay

		relation.revenge_a = max(
			relation.revenge_a,
			0.0
		)

		relation.revenge_b = max(
			relation.revenge_b,
			0.0
		)

		var total_revenge: float = (
			relation.revenge_a
			+ relation.revenge_b
		)

		if total_revenge > 0.0:
			relation.relation -= (
				total_revenge * 0.01
			)

			relation.trust -= (
				total_revenge * 0.005
			)

		relation.relation = clamp(
			relation.relation,
			-100.0,
			100.0
		)

		relation.trust = clamp(
			relation.trust,
			0.0,
			100.0
		)

		if (
			relation.revenge_a <= 0.0
			and relation.revenge_b <= 0.0
		):
			relation.war_ended_year = -1
			relation.last_war_winner = -1


func _cleanup_finished_wars() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			continue

		if relation.war_years <= 0:
			continue

		relation.war_years = 0
		relation.war_score = 0.0


# =====================================================
# RECHERCHE DES DONNÉES
# =====================================================

func _get_all_civilizations() -> Array[CivilizationData]:
	var civilizations: Array[CivilizationData] = []

	for system in _systems.values():
		var planets: Array[PlanetData] = (
			system.get(
				"planets",
				[]
			)
		)

		for planet in planets:
			if planet == null:
				continue

			if planet.civilization == null:
				continue

			var civilization: CivilizationData = (
				planet.civilization
			)

			if civilizations.has(
				civilization
			):
				continue

			civilizations.append(
				civilization
			)

	return civilizations


func _find_civilization(
	civilization_id: int
) -> CivilizationData:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	for civilization in civilizations:
		if civilization == null:
			continue

		if civilization.global_id == civilization_id:
			return civilization

	return null


func _find_planet_by_global_id(
	planet_id: int
) -> PlanetData:

	return _planets.get(
		planet_id,
		null
	)


func _find_system_containing_planet(
	planet_id: int
) -> Dictionary:
	for system in _systems.values():
		var planets: Array[PlanetData] = (
			system.get(
				"planets",
				[]
			)
		)

		for planet in planets:
			if planet == null:
				continue

			if planet.global_id == planet_id:
				return system

	return {}


# =====================================================
# IDS DYNAMIQUES
# =====================================================

func _find_next_civilization_id() -> int:
	var result: int = _next_civilization_id

	_next_civilization_id += 1

	return result

func _generate_civilization_global_id() -> int:
	var result: int = _next_civilization_global_id

	_next_civilization_global_id += 1

	return result

# =====================================================
# API PUBLIQUE
# =====================================================

func get_system(
	system_id: int
) -> Dictionary:
	if not _systems.has(system_id):
		return {}

	return _systems[system_id]


func get_civilization(
	civilization_id: int
) -> CivilizationData:

	if not _civilizations.has(civilization_id):
		return null

	return _civilizations[civilization_id]


func get_civilization_relations(
	civilization_id: int
) -> Array[RelationData]:
	var relations: Array[RelationData] = []

	for relation in _relations.values():
		if relation == null:
			continue

		if (
			relation.civilization_a_id
			== civilization_id
			or relation.civilization_b_id
			== civilization_id
		):
			relations.append(
				relation
			)

	return relations

func get_other_civilization_id(
	relation: RelationData,
	civilization_id: int
) -> int:
	if relation == null:
		return -1

	if relation.civilization_a_id == civilization_id:
		return relation.civilization_b_id

	if relation.civilization_b_id == civilization_id:
		return relation.civilization_a_id

	return -1


func get_controlled_system_count(
	civilization_id: int
) -> int:
	if not _civilization_controlled_system_ids.has(
		civilization_id
	):
		return 0

	var controlled = _civilization_controlled_system_ids[
		civilization_id
	]

	if controlled == null:
		return 0

	return controlled.size()


func _involves_player(civilization_ids: Array) -> bool:
	if player_civilization_id == -1:
		return false

	return civilization_ids.has(player_civilization_id)


func _log_event(
	event_text: String,
	civilization_ids: Array = []
) -> void:
	var involves_player: bool = _involves_player(
		civilization_ids
	)

	print(event_text)

	event_logged.emit(event_text, involves_player)

func _find_system_containing_civilization(
	civilization_id: int
) -> Dictionary:

	var system_id = (
		_civilization_system_ids.get(
			civilization_id,
			null
		)
	)

	if system_id == null:
		return {}

	return _systems.get(
		system_id,
		{}
	)

func _get_civilization_colonies(
	civilization: CivilizationData
) -> Array[ColonyData]:
	var result: Array[ColonyData] = []

	if civilization == null:
		return result

	for colony in civilization.colonies:
		if colony == null:
			continue

		result.append(colony)

	return result

func _capture_colony(
	winner: CivilizationData,
	loser: CivilizationData
) -> void:
	if winner == null:
		return

	if loser == null:
		return

	if loser.colonies.is_empty():
		return

	var winner_systems: Array = (
		_civilization_controlled_system_ids.get(
			winner.global_id,
			[]
		)
	)

	var target_colony: ColonyData = null
	var best_score: float = -INF
	var target_defense_strength: float = 0.0

	for colony in loser.colonies:
		if colony == null:
			continue

		var system_value = (
			_planet_system_ids.get(
				colony.planet_id,
				null
			)
		)

		if system_value == null:
			continue

		var system_id: int = (
			int(system_value)
		)

		var target_position: Vector2 = (
			_system_positions.get(
				system_id,
				Vector2.INF
			)
		)

		if target_position == Vector2.INF:
			continue

		var closest_distance: float = INF

		for winner_system_value in winner_systems:
			var winner_system_id: int = (
				int(winner_system_value)
			)

			var winner_position: Vector2 = (
				_system_positions.get(
					winner_system_id,
					Vector2.INF
				)
			)

			if winner_position == Vector2.INF:
				continue

			var distance: float = (
				winner_position.distance_to(
					target_position
				)
			)

			if distance < closest_distance:
				closest_distance = distance

		if closest_distance == INF:
			continue

		var proximity_score: float = (
			1.0
			/ max(
				closest_distance,
				1.0
			)
		)

		proximity_score *= 1000.0

		var economic_score: float = (
			colony.production * 2.0
		)

		var population_score: float = min(
			float(colony.population)
			/ 10000000.0,
			20.0
		)

		var stability_score: float = (
			100.0 - colony.stability
		)

		var development_score: float = (
			colony.development * 0.50
		)

		var defense_strength: float = (
			_calculate_colony_defense_strength(
				loser,
				colony
			)
		)

		var vulnerability: float = (
			100.0 - defense_strength
		)

		var strategic_score: float = (
			proximity_score
		)

		strategic_score += (
			economic_score
		)

		strategic_score += (
			population_score
		)

		strategic_score += (
			development_score
		)

		strategic_score += (
			stability_score * 2.0
		)

		strategic_score += (
			vulnerability * 1.5
		)

		var target_system_pressure: float = (
			_calculate_territorial_pressure(
				winner,
				system_id
			)
		)

		strategic_score += (
			target_system_pressure * 0.50
		)

		if _contested_systems.has(
			system_id
		):
			strategic_score += 25.0

		if closest_distance <= (
			winner.get_interaction_range()
		):
			strategic_score += 20.0

		if strategic_score <= best_score:
			continue

		best_score = strategic_score
		target_colony = colony
		target_defense_strength = defense_strength

	if target_colony == null:
		return

	var planet_id: int = (
		target_colony.planet_id
	)

	var target_planet: PlanetData = (
		_planets.get(
			planet_id,
			null
		)
	)

	if target_planet == null:
		return

	var target_system_value = (
		_planet_system_ids.get(
			planet_id,
			null
		)
	)

	if target_system_value == null:
		return

	var target_system_id: int = (
		int(target_system_value)
	)

	loser.remove_colony(
		planet_id
	)

	winner.take_over_colony(
		target_colony
	)

	target_colony.set_occupied()

	target_planet.colony_owner_id = (
		winner.global_id
	)

	if not _civilization_controlled_system_ids.has(
		winner.global_id
	):
		_civilization_controlled_system_ids[
			winner.global_id
	] = []

	var winner_controlled_systems: Array = (
		_civilization_controlled_system_ids[
			winner.global_id
		]
	)

	if not winner_controlled_systems.has(
		target_system_id
	):
		winner_controlled_systems.append(
			target_system_id
		)

	_update_claims_after_conquest(
		winner,
		loser,
		target_system_id
	)

	_log_event(
		"[Conquête] "
		+ winner.name
		+ " capture la colonie #"
		+ str(planet_id)
		+ " dans le système #"
		+ str(target_system_id)
		+ " de "
		+ loser.name
		+ " (défense : "
		+ str(round(target_defense_strength))
		+ ")",
		[winner.global_id, loser.global_id]
	)

func _rebuild_civilization_allies() -> void:
	_civilization_allies.clear()
	_civilization_allies_dirty = true

	for relation in _relations.values():
		if relation == null:
			continue

		if not relation.alliance:
			continue

		if relation.at_war:
			continue

		var civilization_a_id: int = (
			relation.civilization_a_id
		)

		var civilization_b_id: int = (
			relation.civilization_b_id
		)

		if not _civilization_allies.has(
			civilization_a_id
		):
			_civilization_allies[
				civilization_a_id
			] = []

		if not _civilization_allies.has(
			civilization_b_id
		):
			_civilization_allies[
				civilization_b_id
			] = []

		_civilization_allies[
			civilization_a_id
		].append(
			civilization_b_id
		)

		_civilization_allies[
			civilization_b_id
		].append(
			civilization_a_id
		)

func _get_civilization_grid_cell(
	position: Vector2
) -> Vector2i:
	return Vector2i(
		floori(
			position.x
			/ CIVILIZATION_SPATIAL_CELL_SIZE
		),
		floori(
			position.y
			/ CIVILIZATION_SPATIAL_CELL_SIZE
		)
	)

func _build_civilization_spatial_grid() -> void:
	_civilization_spatial_grid.clear()

	for civilization in _civilizations.values():
		if civilization == null:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		if not _civilization_positions.has(
			civilization_id
		):
			continue

		var position: Vector2 = (
			_civilization_positions[
				civilization_id
			]
		)

		var cell: Vector2i = (
			_get_civilization_grid_cell(
				position
			)
		)

		if not _civilization_spatial_grid.has(
			cell
		):
			_civilization_spatial_grid[
				cell
			] = []

		_civilization_spatial_grid[
			cell
		].append(
			civilization_id
		)

func _build_colonizable_planet_spatial_grid() -> void:
	_colonizable_planet_spatial_grid.clear()

	for planet in _colonizable_planets:
		if planet == null:
			continue

		var system_id = (
			_colonizable_planet_system_ids.get(
				planet.global_id,
				null
			)
		)

		if system_id == null:
			continue

		var position: Vector2 = (
			_system_positions.get(
				system_id,
				Vector2.INF
			)
		)

		if position == Vector2.INF:
			continue

		var cell: Vector2i = (
			_get_civilization_grid_cell(
				position
			)
		)

		if not _colonizable_planet_spatial_grid.has(
			cell
		):
			_colonizable_planet_spatial_grid[
				cell
			] = []

		_colonizable_planet_spatial_grid[
			cell
		].append(
			planet.global_id
		)

func _evaluate_war_decisions() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		if not civilization_a.knows_civilization(
			civilization_b.global_id
		):
			continue

		if not civilization_b.knows_civilization(
			civilization_a.global_id
		):
			continue

		if not civilization_a.wants_to_declare_war(
			civilization_b
		):
			continue

		if relation.relation > -20.0:
			continue

		var war_cost: float = (
			civilization_a.get_war_cost_aversion(
				civilization_b,
				relation
			)
		)

		# Plus le coût économique est élevé,
		# plus la civilisation hésite.
		var war_threshold: float = (
			20.0
			+ war_cost * 0.50
		)

		if relation.relation > -war_threshold:
			continue

		# Une dépendance extrême peut empêcher
		# complètement une guerre tant que la relation
		# n'est pas catastrophique.
		if war_cost >= 80.0 \
		and relation.relation > -80.0:
			continue

		relation.at_war = true
		relation.war_years = 0
		relation.war_score = 0.0
		relation.last_war_winner = -1
		relation.war_ended_year = -1

		relation.alliance = false

		relation.event_history.append(
			"Année "
			+ str(current_year)
			+ " : "
			+ civilization_a.name
			+ " déclare la guerre à "
			+ civilization_b.name
			+ "."
		)

		if relation.event_history.size() > 20:
			relation.event_history.pop_front()

		_log_event(
			"[Guerre] "
			+ civilization_a.name
			+ " déclare la guerre à "
			+ civilization_b.name
			+ " (coût économique : "
			+ str(war_cost)
			+ ")",
			[
				civilization_a.global_id,
				civilization_b.global_id,
			]
		)

func _evaluate_trade_decisions() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			relation.trade = 0.0
			relation.trade_value = 0.0
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		if not civilization_a.knows_civilization(
			civilization_b.global_id
		):
			relation.trade = 0.0
			relation.trade_value = 0.0
			continue

		if not civilization_b.knows_civilization(
			civilization_a.global_id
		):
			relation.trade = 0.0
			relation.trade_value = 0.0
			continue

		if relation.relation < -20.0:
			relation.trade = max(
				relation.trade - 5.0,
				0.0
			)

			relation.trade_value = 0.0
			continue

		var attractiveness_a: float = (
			civilization_a.get_trade_attractiveness(
				civilization_b
			)
		)

		var attractiveness_b: float = (
			civilization_b.get_trade_attractiveness(
				civilization_a
			)
		)

		var demand_a: float = (
			civilization_a.get_trade_demand(
				civilization_b
			)
		)

		var demand_b: float = (
			civilization_b.get_trade_demand(
				civilization_a
			)
		)

		var trade_potential_a: float = (
			attractiveness_a
			+ demand_b
		)

		var trade_potential_b: float = (
			attractiveness_b
			+ demand_a
		)

		var trade_potential: float = (
			(
				trade_potential_a
				+ trade_potential_b
			)
			* 0.25
		)

		var relation_factor: float = (
			(relation.relation + 100.0)
			* 0.005
		)

		var trust_factor: float = (
			relation.trust
			* 0.005
		)

		var commerce_factor: float = (
			(
				civilization_a.commerce
				+ civilization_b.commerce
			)
			* 0.005
		)

		var target_trade: float = (
			trade_potential
			* relation_factor
			* (
				0.5
				+ trust_factor
				+ commerce_factor
			)
		)

		target_trade = clamp(
			target_trade,
			0.0,
			100.0
		)

		if target_trade > relation.trade:
			relation.trade += min(
				target_trade - relation.trade,
				5.0
			)
		else:
			relation.trade -= min(
				relation.trade - target_trade,
				3.0
			)

		relation.trade = clamp(
			relation.trade,
			0.0,
			100.0
		)

		relation.trade_value = (
			relation.trade
			* (
				civilization_a.economy
				+ civilization_b.economy
			)
			* 0.01
		)

		var trade_income: float = (
			relation.trade_value
			* 0.01
		)

		civilization_a.add_trade_income(
			trade_income
		)

		civilization_b.add_trade_income(
			trade_income
		)

		if relation.trade >= 40.0:
			_share_territories_between_civilizations(
				civilization_a,
				civilization_b,
				relation
			)

func _simulate_exploration() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.is_empty():
		return

	for civilization in civilizations:
		if civilization == null:
			continue

		if not civilization.wants_to_explore():
			continue

		var exploration_range: float = (
			civilization.get_interaction_range()
		)

		if exploration_range <= 0.0:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		var previous_range: float = float(
			_civilization_exploration_ranges.get(
				civilization_id,
				-1.0
			)
		)

		var frontier: Dictionary = (
			_civilization_exploration_frontiers.get(
				civilization_id,
				{}
			)
		)

		# Première initialisation ou changement
		# de niveau spatial.
		if previous_range != exploration_range:
			_rebuild_exploration_frontier(
				civilization,
				exploration_range
			)

			frontier = (
				_civilization_exploration_frontiers.get(
					civilization_id,
					{}
				)
			)

		if frontier.is_empty():
			continue

		# Nettoyage léger des candidats devenus connus
		# par un autre mécanisme de découverte.
		for system_value in frontier.keys():
			var system_id: int = (
				int(system_value)
			)

			if civilization.has_explored_system(
				system_id
			):
				frontier.erase(system_value)

		if frontier.is_empty():
			continue

		var candidate_system_ids: Array = (
			frontier.keys()
		)

		if candidate_system_ids.is_empty():
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = (
			civilization.seed
			+ current_year * 1543
			+ civilization.explored_system_ids.size()
			* 7919
		)

		var discovered_index: int = (
			rng.randi_range(
				0,
				candidate_system_ids.size() - 1
			)
		)

		var discovered_system_id: int = (
			int(
				candidate_system_ids[
					discovered_index
				]
			)
		)

		# Le système quitte immédiatement la frontière.
		frontier.erase(
			discovered_system_id
		)

		civilization.explore_system(
			discovered_system_id
		)

		print(
			"[Exploration] ",
			civilization.name,
			" découvre le système #",
			discovered_system_id
		)

		# Le nouveau système devient à son tour
		# une source d'exploration.
		_expand_exploration_frontier(
			civilization,
			discovered_system_id,
			exploration_range
		)

		var discovered_civilization: CivilizationData = (
			_find_civilization_in_system(
				discovered_system_id
			)
		)

		if discovered_civilization == null:
			continue

		if discovered_civilization.global_id == (
			civilization.global_id
		):
			continue

		# Premier contact.
		var already_known: bool = (
			civilization.knows_civilization(
				discovered_civilization.global_id
			)
		)

		civilization.discover_civilization(
			discovered_civilization.global_id
		)

		discovered_civilization.discover_civilization(
			civilization.global_id
		)

		# La civilisation exploratrice découvre
		# le système de la civilisation rencontrée.
		var discovered_civilization_system_id = (
			_civilization_system_ids.get(
				discovered_civilization.global_id,
				null
			)
		)

		if discovered_civilization_system_id != null:
			civilization.discover_civilization_system(
				discovered_civilization.global_id,
				discovered_civilization_system_id
			)

		# La civilisation rencontrée découvre
		# le système de la civilisation exploratrice.
		var explorer_system_id = (
			_civilization_system_ids.get(
				civilization.global_id,
				null
			)
		)

		if explorer_system_id != null:
			discovered_civilization.discover_civilization_system(
				civilization.global_id,
				explorer_system_id
			)

		# Si le système contient une colonie,
		# son propriétaire est identifié.
		var discovered_colony: PlanetData = (
			_find_civilization_colony_in_system(
				discovered_system_id,
				discovered_civilization.global_id
			)
		)

		if discovered_colony != null:
			civilization.discover_civilization_system(
				discovered_civilization.global_id,
				discovered_system_id
			)

			print(
				"[Exploration] ",
				civilization.name,
				" découvre une colonie de ",
				discovered_civilization.name,
				" dans le système #",
				discovered_system_id
			)

		# Une relation n'est créée que lors du premier contact.
		if already_known:
			continue

		var relation: RelationData = (
			_create_relation(
				civilization,
				discovered_civilization
			)
		)

		if relation == null:
			continue

		relation.event_history.append(
			"Année "
			+ str(current_year)
			+ " : premier contact entre "
			+ civilization.name
			+ " et "
			+ discovered_civilization.name
			+ "."
		)

		if relation.event_history.size() > 20:
			relation.event_history.pop_front()

		_log_event(
			"[Premier contact] "
			+ civilization.name
			+ " rencontre "
			+ discovered_civilization.name,
			[
				civilization.global_id,
				discovered_civilization.global_id,
			]
		)

func _find_civilization_in_system(
	system_id: int
) -> CivilizationData:
	var civilizations: Array[CivilizationData] = (
		_get_system_civilization_owners(
			system_id
		)
	)

	if civilizations.is_empty():
		return null

	return civilizations[0]

func _find_civilization_colony_in_system(
	system_id: int,
	civilization_id: int
) -> PlanetData:
	var planets: Array[PlanetData] = (
		_system_planets.get(
			system_id,
			[]
		)
	)

	for planet in planets:
		if planet == null:
			continue

		if planet.colony_owner_id != civilization_id:
			continue

		return planet

	return null


func _share_known_territories(
	civilization_a: CivilizationData,
	civilization_b: CivilizationData,
	relation: RelationData
) -> void:
	if civilization_a == null:
		return

	if civilization_b == null:
		return

	if relation == null:
		return

	if not civilization_a.knows_civilization(
		civilization_b.global_id
	):
		return

	if not civilization_b.knows_civilization(
		civilization_a.global_id
	):
		return

	# Une alliance permet un partage important
	# des informations territoriales.
	var share_probability: float = 0.05

	if relation.alliance:
		share_probability = 0.35
	elif relation.trade > 50.0:
		share_probability = 0.15
	elif relation.relation > 50.0:
		share_probability = 0.10

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		civilization_a.seed
		+ civilization_b.seed
		+ current_year * 7919
	)

	if rng.randf() > share_probability:
		return

	if not civilization_b.known_civilization_system_ids.has(
		civilization_a.global_id
	):
		return

	var known_systems: Array = (
		civilization_b.known_civilization_system_ids[
			civilization_a.global_id
		]
	)

	if known_systems.is_empty():
		return

	# Une information est partagée à la fois.
	var system_id: int = (
		int(
			known_systems[
				rng.randi_range(
					0,
					known_systems.size() - 1
				)
			]
		)
	)

	civilization_a.discover_civilization_system(
		civilization_b.global_id,
		system_id
	)

	print(
		"[Diplomatie] ",
		civilization_a.name,
		" partage des informations avec ",
		civilization_b.name,
		" concernant le système #",
		system_id
	)

func _share_territories_between_civilizations(
	civilization_a: CivilizationData,
	civilization_b: CivilizationData,
	relation: RelationData
) -> void:
	if civilization_a == null:
		return

	if civilization_b == null:
		return

	if relation == null:
		return

	if civilization_a.global_id == civilization_b.global_id:
		return

	# Les informations ne peuvent être partagées
	# que si les deux civilisations se connaissent.
	if not civilization_a.knows_civilization(
		civilization_b.global_id
	):
		return

	if not civilization_b.knows_civilization(
		civilization_a.global_id
	):
		return

	# Une guerre empêche le partage d'informations.
	if relation.at_war:
		return

	# Partage dans les deux directions.
	_share_known_territories(
		civilization_a,
		civilization_b,
		relation
	)

	_share_known_territories(
		civilization_b,
		civilization_a,
		relation
	)

func _calculate_territorial_pressure(
	civilization: CivilizationData,
	target_system_id: int
) -> float:
	if civilization == null:
		return 0.0

	var target_position: Vector2 = (
		_system_positions.get(
			target_system_id,
			Vector2.INF
		)
	)

	if target_position == Vector2.INF:
		return 0.0

	var controlled_systems: Array = (
		_civilization_controlled_system_ids.get(
			civilization.global_id,
			[]
		)
	)

	if controlled_systems.is_empty():
		return 0.0

	var closest_distance: float = INF

	for controlled_system_value in controlled_systems:
		var controlled_system_id: int = (
			int(controlled_system_value)
		)

		var controlled_position: Vector2 = (
			_system_positions.get(
				controlled_system_id,
				Vector2.INF
			)
		)

		if controlled_position == Vector2.INF:
			continue

		var distance: float = (
			controlled_position.distance_to(
				target_position
			)
		)

		if distance < closest_distance:
			closest_distance = distance

	if closest_distance == INF:
		return 0.0

	var interaction_range: float = (
		civilization.get_interaction_range()
	)

	if interaction_range <= 0.0:
		return 0.0

	var pressure: float = (
		1.0
		- closest_distance / interaction_range
	)

	pressure = clamp(
		pressure,
		0.0,
		1.0
	)

	return pressure * 100.0


func _evaluate_territorial_tensions() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.size() < 2:
		return

	var territories: Array = []

	for civilization in civilizations:
		if civilization == null:
			continue

		var controlled_systems: Array = (
			_civilization_controlled_system_ids.get(
				civilization.global_id,
				[]
			)
		)

		if controlled_systems.is_empty():
			continue

		var range: float = (
			civilization.get_interaction_range()
		)

		if range <= 0.0:
			continue

		var positions: Array[Vector2] = []
		var min_x: float = INF
		var max_x: float = -INF
		var min_y: float = INF
		var max_y: float = -INF

		for system_value in controlled_systems:
			var position: Vector2 = (
				_system_positions.get(
					int(system_value),
					Vector2.INF
				)
			)

			if position == Vector2.INF:
				continue

			positions.append(
				position
			)

			if position.x < min_x:
				min_x = position.x
			if position.x > max_x:
				max_x = position.x
			if position.y < min_y:
				min_y = position.y
			if position.y > max_y:
				max_y = position.y

		if positions.is_empty():
			continue

		territories.append(
			{
				"civilization": civilization,
				"positions": positions,
				"range": range,
				"min_x": min_x,
				"max_x": max_x,
				"min_y": min_y,
				"max_y": max_y
			}
		)

	for i in territories.size():
		var entry_a: Dictionary = territories[i]

		var civilization_a: CivilizationData = (
			entry_a["civilization"]
		)

		var positions_a: Array = (
			entry_a["positions"]
		)

		for j in range(i + 1, territories.size()):
			var entry_b: Dictionary = territories[j]

			var civilization_b: CivilizationData = (
				entry_b["civilization"]
			)

			var combined_range: float = (
				entry_a["range"] + entry_b["range"]
			)

			if combined_range <= 0.0:
				continue

			# Élimination rapide par boîtes englobantes :
			# si les territoires sont trop éloignés, aucune
			# paire de systèmes ne peut générer de tension.
			var min_dx: float = max(
				entry_a["max_x"] - entry_b["min_x"],
				entry_b["max_x"] - entry_a["min_x"]
			)

			var min_dy: float = max(
				entry_a["max_y"] - entry_b["min_y"],
				entry_b["max_y"] - entry_a["min_y"]
			)

			if min_dx < 0.0:
				min_dx = 0.0

			if min_dy < 0.0:
				min_dy = 0.0

			var combined_range_squared: float = (
				combined_range * combined_range
			)

			if (
				min_dx * min_dx
				+ min_dy * min_dy
				> combined_range_squared
			):
				continue

			var positions_b: Array = (
				entry_b["positions"]
			)

			var closest_distance: float = INF

			for position_a in positions_a:
				for position_b in positions_b:
					var distance: float = (
						position_a.distance_to(
							position_b
						)
					)

					if distance < closest_distance:
						closest_distance = distance

			if closest_distance == INF:
				continue

			if closest_distance > combined_range:
				continue

			var relation_key: String = (
				_get_relation_key(
					civilization_a.global_id,
					civilization_b.global_id
				)
			)

			if relation_key.is_empty():
				continue

			var relation: RelationData = (
				_relations.get(
					relation_key,
					null
				)
			)

			if relation == null:
				continue

			if relation.at_war:
				continue

			var proximity_factor: float = (
				1.0
				- (
					closest_distance
					/ combined_range
				)
			)

			proximity_factor = clamp(
				proximity_factor,
				0.0,
				1.0
			)

			var expansionism_factor: float = (
				(
					civilization_a.expansionism
					+ civilization_b.expansionism
				)
				- 100.0
			)

			var militarism_factor: float = (
				(
					civilization_a.militarism
					+ civilization_b.militarism
				)
				- 100.0
			)

			var tension: float = 0.0

			tension += (
				expansionism_factor
				* 0.002
				* proximity_factor
			)

			tension += (
				militarism_factor
				* 0.001
				* proximity_factor
			)

			if tension <= 0.0:
				continue

			relation.relation -= tension

			relation.relation = clamp(
				relation.relation,
				-100.0,
				100.0
			)

func _apply_war_damage(
	civilization_a: CivilizationData,
	civilization_b: CivilizationData,
	relation: RelationData
) -> void:
	if civilization_a == null:
		return

	if civilization_b == null:
		return

	if relation == null:
		return

	if not relation.at_war:
		return

	var power_a: float = (
		max(
			civilization_a.military_power,
			1.0
		)
	)

	var power_b: float = (
		max(
			civilization_b.military_power,
			1.0
		)
	)

	var total_power: float = (
		power_a + power_b
	)

	if total_power <= 0.0:
		return

	var damage_a: float = (
		power_b / total_power
	)

	var damage_b: float = (
		power_a / total_power
	)

	damage_a *= 0.02
	damage_b *= 0.02

	for colony in civilization_a.colonies:
		if colony == null:
			continue

		colony.stability = max(
			colony.stability - damage_a * 10.0,
			0.0
		)

		colony.production = max(
			colony.production - damage_a * 2.0,
			0.0
		)

		var population_loss_a: int = max(
			1,
			int(
				float(colony.population)
				* damage_a
			)
		)

		colony.population = max(
			colony.population - population_loss_a,
			1
		)

	for colony in civilization_b.colonies:
		if colony == null:
			continue

		colony.stability = max(
			colony.stability - damage_b * 10.0,
			0.0
		)

		colony.production = max(
			colony.production - damage_b * 2.0,
			0.0
		)

		var population_loss_b: int = max(
			1,
			int(
				float(colony.population)
				* damage_b
			)
		)

		colony.population = max(
			colony.population - population_loss_b,
			1
		)

func _update_controlled_territories() -> void:
	for civilization_id in _civilization_controlled_system_ids.keys():
		var controlled_systems: Array = (
			_civilization_controlled_system_ids[
				civilization_id
			]
		)

		var valid_systems: Array = []

		for system_value in controlled_systems:
			var system_id: int = (
				int(system_value)
			)

			if not _systems.has(system_id):
				continue

			if not _civilization_has_presence_in_system(
				int(civilization_id),
				system_id
			):
				continue

			var owners: Array[CivilizationData] = (
				_get_system_civilization_owners(
					system_id
				)
			)

			if owners.is_empty():
				continue

			# Une civilisation qui possède le monde principal
			# conserve le contrôle du système.
			if _civilization_has_homeworld_in_system(
				int(civilization_id),
				system_id
			):
				valid_systems.append(
					system_id
				)
				continue

			# S'il n'existe qu'un seul propriétaire présent,
			# sa colonie peut également établir le contrôle.
			if owners.size() == 1:
				if owners[0].global_id == int(civilization_id):
					valid_systems.append(
						system_id
					)

		_civilization_controlled_system_ids[
			civilization_id
		] = valid_systems

	# Réintégration des systèmes d'origine.
	for civilization in _get_all_civilizations():
		if civilization == null:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		if not _civilization_controlled_system_ids.has(
			civilization_id
		):
			_civilization_controlled_system_ids[
				civilization_id
			] = []

		var controlled_systems: Array = (
			_civilization_controlled_system_ids[
				civilization_id
			]
		)

		var home_system_value = (
			_civilization_system_ids.get(
				civilization_id,
				null
			)
		)

		if home_system_value == null:
			continue

		var home_system_id: int = (
			int(home_system_value)
		)

		if not _civilization_has_homeworld_in_system(
			civilization_id,
			home_system_id
		):
			continue

		if not controlled_systems.has(
			home_system_id
		):
			controlled_systems.append(
				home_system_id
			)

		_civilization_controlled_system_ids[
			civilization_id
		] = controlled_systems

func _update_territorial_claims() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	_civilization_system_closest_distances.clear()

	if civilizations.is_empty():
		return

	_rebuild_system_spatial_grid()

	for civilization in civilizations:
		if civilization == null:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		if not _civilization_territorial_claims.has(
			civilization_id
		):
			_civilization_territorial_claims[
				civilization_id
			] = {}

		var claims: Dictionary = (
			_civilization_territorial_claims[
				civilization_id
			]
		)

		var controlled_systems: Array = (
			_civilization_controlled_system_ids.get(
				civilization_id,
				[]
			)
		)

		if controlled_systems.is_empty():
			claims.clear()

			_civilization_claim_distance_cache.erase(
				civilization_id
			)

			continue

		var interaction_range: float = (
			civilization.get_interaction_range()
		)

		if interaction_range <= 0.0:
			claims.clear()

			_civilization_claim_distance_cache.erase(
				civilization_id
			)

			continue

		var cache_entry = (
			_civilization_claim_distance_cache.get(
				civilization_id,
				null
			)
		)

		var cache_valid: bool = false

		if cache_entry != null:
			var cached_controlled_systems: Array = (
				cache_entry[
					"controlled_systems"
				]
			)

			var cached_interaction_range: float = (
				float(
					cache_entry[
						"interaction_range"
					]
				)
			)

			if (
				cached_controlled_systems.size()
				== controlled_systems.size()
				and cached_interaction_range
				== interaction_range
			):
				cache_valid = true

				for index in controlled_systems.size():
					if (
						int(
							controlled_systems[index]
						)
						!= int(
							cached_controlled_systems[index]
						)
					):
						cache_valid = false
						break

		var closest_distances: Dictionary

		if cache_valid:
			closest_distances = (
				cache_entry[
					"closest_distances"
				]
			)
		else:
			var interaction_range_squared: float = (
				interaction_range
				* interaction_range
			)

			closest_distances = {}

			var controlled_lookup: Dictionary = {}
			var controlled_positions: Array[Vector2] = []

			for controlled_system_value in controlled_systems:
				var controlled_system_id: int = (
					int(controlled_system_value)
				)

				controlled_lookup[
					controlled_system_id
				] = true

				var controlled_position: Vector2 = (
					_system_positions.get(
						controlled_system_id,
						Vector2.INF
					)
				)

				if controlled_position != Vector2.INF:
					controlled_positions.append(
						controlled_position
					)

			if controlled_positions.is_empty():
				closest_distances = {}
			else:
				var cell_radius: int = ceili(
					interaction_range
					/ SYSTEM_SPATIAL_CELL_SIZE
				)

				var neighbor_cells: Dictionary = {}

				for controlled_position in controlled_positions:
					var center_x: int = floori(
						controlled_position.x
						/ SYSTEM_SPATIAL_CELL_SIZE
					)

					var center_y: int = floori(
						controlled_position.y
						/ SYSTEM_SPATIAL_CELL_SIZE
					)

					for offset_x in range(
						-cell_radius,
						cell_radius + 1
					):
						for offset_y in range(
							-cell_radius,
							cell_radius + 1
						):
							neighbor_cells[
								Vector2i(
									center_x + offset_x,
									center_y + offset_y
								)
							] = true

				for cell_key in neighbor_cells.keys():
					var systems_in_cell: Array = (
						_system_spatial_grid.get(
							cell_key,
							[]
						)
					)

					for system_value in systems_in_cell:
						var system_id: int = (
							int(system_value)
						)

						if controlled_lookup.has(
							system_id
						):
							continue

						var target_position: Vector2 = (
							_system_positions.get(
								system_id,
								Vector2.INF
							)
						)

						if target_position == Vector2.INF:
							continue

						var distance_squared: float = INF

						for controlled_position in (
							controlled_positions
						):
							var candidate_distance: float = (
								controlled_position.distance_squared_to(
									target_position
								)
							)

							if candidate_distance < (
								distance_squared
							):
								distance_squared = (
									candidate_distance
								)

						if distance_squared > (
							interaction_range_squared
						):
							continue

						var previous_distance = (
							closest_distances.get(
								system_id,
								INF
							)
						)

						if distance_squared < (
							float(
								previous_distance
							)
						):
							closest_distances[
								system_id
							] = distance_squared

			_civilization_claim_distance_cache[
				civilization_id
			] = {
				"controlled_systems":
					controlled_systems.duplicate(),
				"interaction_range":
					interaction_range,
				"closest_distances":
					closest_distances
			}

		if closest_distances.is_empty():
			claims.clear()
			continue

		_civilization_system_closest_distances[
			civilization_id
		] = closest_distances

		var expansionism_bonus: float = (
			civilization.expansionism
			* 0.20
		)

		var militarism_bonus: float = (
			civilization.militarism
			* 0.05
		)

		var inverse_interaction_range: float = (
			1.0 / interaction_range
		)

		claims.clear()

		for system_value in closest_distances.keys():
			var system_id: int = (
				int(system_value)
			)

			var closest_distance_squared: float = (
				float(
					closest_distances[
						system_value
					]
				)
			)

			var closest_distance: float = sqrt(
				closest_distance_squared
			)

			var proximity: float = (
				1.0
				- closest_distance
				* inverse_interaction_range
			)

			if proximity < 0.0:
				proximity = 0.0
			elif proximity > 1.0:
				proximity = 1.0

			var influence: float = 0.0

			var system_influences: Dictionary = (
				_civilization_system_influence.get(
					system_id,
					{}
				)
			)

			if system_influences.has(
				civilization_id
			):
				influence = float(
					system_influences[
						civilization_id
					]
				)

			var claim_strength: float = (
				proximity * 40.0
			)

			claim_strength += (
				influence * 0.60
			)

			claim_strength += (
				expansionism_bonus
			)

			claim_strength += (
				militarism_bonus
			)

			if _contested_systems.has(
				system_id
			):
				claim_strength *= 0.85

			if claim_strength > 100.0:
				claim_strength = 100.0
			elif claim_strength < 0.0:
				claim_strength = 0.0

			if claim_strength < 10.0:
				continue

			claims[
				system_id
			] = claim_strength

func _evaluate_territorial_claim_conflicts() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.size() < 2:
		return

	for i in civilizations.size():
		var civilization_a: CivilizationData = (
			civilizations[i]
		)

		if civilization_a == null:
			continue

		var claims_a: Dictionary = (
			_civilization_territorial_claims.get(
				civilization_a.global_id,
				{}
			)
		)

		if claims_a.is_empty():
			continue

		for j in range(i + 1, civilizations.size()):
			var civilization_b: CivilizationData = (
				civilizations[j]
			)

			if civilization_b == null:
				continue

			var claims_b: Dictionary = (
				_civilization_territorial_claims.get(
					civilization_b.global_id,
					{}
				)
			)

			if claims_b.is_empty():
				continue

			var relation_key: String = (
				_get_relation_key(
					civilization_a.global_id,
					civilization_b.global_id
				)
			)

			if relation_key.is_empty():
				continue

			var relation: RelationData = (
				_relations.get(
					relation_key,
					null
				)
			)

			if relation == null:
				continue

			if relation.at_war:
				continue

			for claimed_system_value in claims_a.keys():
				var system_id: int = (
					int(claimed_system_value)
				)

				if not claims_b.has(system_id):
					continue

				var claim_a: float = (
					float(
						claims_a[
							claimed_system_value
						]
					)
				)

				var claim_b: float = (
					float(
						claims_b[
							system_id
						]
					)
				)

				var combined_claim: float = (
					claim_a + claim_b
				)

				if combined_claim < 80.0:
					continue

				var conflict_strength: float = (
					combined_claim - 80.0
				)

				conflict_strength *= 0.002

				var militarism_factor: float = (
					(
						civilization_a.militarism
						+ civilization_b.militarism
					)
					/ 200.0
				)

				var expansionism_factor: float = (
					(
						civilization_a.expansionism
						+ civilization_b.expansionism
					)
					/ 200.0
				)

				var tension: float = (
					conflict_strength
					* (
						0.5
						+ militarism_factor * 0.5
					)
					* (
						0.5
						+ expansionism_factor * 0.5
					)
				)

				if tension <= 0.0:
					continue

				relation.relation -= tension

				relation.relation = clamp(
					relation.relation,
					-100.0,
					100.0
				)

func _create_territorial_demand(
	claiming_civilization: CivilizationData,
	target_civilization: CivilizationData,
	system_id: int,
	relation: RelationData
) -> bool:
	if claiming_civilization == null:
		return false

	if target_civilization == null:
		return false

	if relation == null:
		return false

	if relation.at_war:
		return false

	if system_id < 0:
		return false

	var claims: Dictionary = (
		_civilization_territorial_claims.get(
			claiming_civilization.global_id,
			{}
		)
	)

	if not claims.has(system_id):
		return false

	var claim_strength: float = (
		float(
			claims[system_id]
		)
	)

	if claim_strength < 70.0:
		return false

	if relation.territorial_demands.has(
		system_id
	):
		return false

	relation.territorial_demands[
		system_id
	] = claiming_civilization.global_id

	relation.last_demand_year = current_year

	relation.event_history.append(
		"Année "
		+ str(current_year)
		+ " : "
		+ claiming_civilization.name
		+ " revendique le système #"
		+ str(system_id)
		+ " auprès de "
		+ target_civilization.name
		+ "."
	)

	if relation.event_history.size() > 20:
		relation.event_history.pop_front()

	print(
		"[Diplomatie] ",
		claiming_civilization.name,
		" revendique officiellement le système #",
		system_id,
		" auprès de ",
		target_civilization.name
	)

	return true

func _evaluate_territorial_demands() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.size() < 2:
		return

	for i in civilizations.size():
		var civilization_a: CivilizationData = (
			civilizations[i]
		)

		if civilization_a == null:
			continue

		var claims_a: Dictionary = (
			_civilization_territorial_claims.get(
				civilization_a.global_id,
				{}
			)
		)

		if claims_a.is_empty():
			continue

		for j in range(i + 1, civilizations.size()):
			var civilization_b: CivilizationData = (
				civilizations[j]
			)

			if civilization_b == null:
				continue

			var claims_b: Dictionary = (
				_civilization_territorial_claims.get(
					civilization_b.global_id,
					{}
				)
			)

			if claims_b.is_empty():
				continue

			var relation_key: String = (
				_get_relation_key(
					civilization_a.global_id,
					civilization_b.global_id
				)
			)

			if relation_key.is_empty():
				continue

			var relation: RelationData = (
				_relations.get(
					relation_key,
					null
				)
			)

			if relation == null:
				continue

			if relation.at_war:
				continue

			for system_id_value in claims_a.keys():
				var system_id: int = (
					int(system_id_value)
				)

				if not claims_b.has(system_id):
					continue

				var civilization_a_systems: Array = (
					_civilization_controlled_system_ids.get(
						civilization_a.global_id,
						[]
					)
				)

				var civilization_b_systems: Array = (
					_civilization_controlled_system_ids.get(
						civilization_b.global_id,
						[]
					)
				)

				var a_controls_system: bool = (
					civilization_a_systems.has(
						system_id
					)
				)

				var b_controls_system: bool = (
					civilization_b_systems.has(
						system_id
					)
				)

				# Une demande territoriale concerne un
				# territoire réellement contrôlé par l'autre.
				if not a_controls_system \
				and not b_controls_system:
					continue

				var claim_a: float = (
					float(
						claims_a[
							system_id_value
						]
					)
				)

				var claim_b: float = (
					float(
						claims_b[
							system_id
						]
					)
				)

				if claim_a < 70.0:
					continue

				if claim_b < 70.0:
					continue

				if a_controls_system \
				and not b_controls_system:
					continue

				if b_controls_system \
				and not a_controls_system:
					continue

				if claim_a >= claim_b:
					_create_territorial_demand(
						civilization_a,
						civilization_b,
						system_id,
						relation
					)
				else:
					_create_territorial_demand(
						civilization_b,
						civilization_a,
						system_id,
						relation
					)

func _resolve_territorial_demand(
	relation: RelationData,
	demanding_civilization: CivilizationData,
	target_civilization: CivilizationData,
	system_id: int
) -> void:
	if relation == null:
		return

	if demanding_civilization == null:
		return

	if target_civilization == null:
		return

	if not relation.territorial_demands.has(
		system_id
	):
		return

	if relation.at_war:
		relation.territorial_demands.erase(
			system_id
		)
		return

	var military_a: float = (
		demanding_civilization.military_power
	)

	var military_b: float = (
		target_civilization.military_power
	)

	var military_total: float = (
		max(
			military_a + military_b,
			1.0
		)
	)

	var military_ratio: float = (
		military_a / military_total
	)

	var acceptance_score: float = 50.0

	# Une bonne relation favorise l'acceptation.
	acceptance_score += (
		relation.relation * 0.25
	)

	acceptance_score += (
		relation.trust * 0.15
	)

	# Une grande différence militaire favorise
	# l'acceptation de la demande.
	acceptance_score += (
		(
			military_ratio - 0.5
		) * 60.0
	)

	# Une civilisation expansionniste refuse
	# plus facilement de céder.
	acceptance_score -= (
		target_civilization.expansionism
		* 0.25
	)

	# La diplomatie augmente la volonté de compromis.
	acceptance_score += (
		target_civilization.diplomacy
		* 0.20
	)

	acceptance_score = clamp(
		acceptance_score,
		0.0,
		100.0
	)

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		demanding_civilization.seed
		+ target_civilization.seed
		+ system_id * 7919
		+ current_year * 997
	)

	var random_value: float = (
		rng.randf_range(
			-10.0,
			10.0
		)
	)

	acceptance_score += random_value

	if acceptance_score >= 60.0:
		# La civilisation accepte la demande.
		_transfer_territorial_system(
			demanding_civilization,
			target_civilization,
			system_id
		)

		relation.relation += 10.0
		relation.trust += 5.0

		relation.relation = clamp(
			relation.relation,
			-100.0,
			100.0
		)

		relation.trust = clamp(
			relation.trust,
			0.0,
			100.0
		)

		relation.event_history.append(
			"Année "
			+ str(current_year)
			+ " : "
			+ target_civilization.name
			+ " accepte de céder le système #"
			+ str(system_id)
			+ "."
		)

		print(
			"[Diplomatie] ",
			target_civilization.name,
			" cède le système #",
			system_id,
			" à ",
			demanding_civilization.name
		)

	else:
		# Refus.
		relation.relation -= 10.0
		relation.trust -= 5.0

		relation.relation = clamp(
			relation.relation,
			-100.0,
			100.0
		)

		relation.trust = clamp(
			relation.trust,
			0.0,
			100.0
		)

		relation.event_history.append(
			"Année "
			+ str(current_year)
			+ " : "
			+ target_civilization.name
			+ " refuse la revendication du système #"
			+ str(system_id)
			+ "."
		)

		print(
			"[Diplomatie] ",
			target_civilization.name,
			" refuse de céder le système #",
			system_id
		)

	relation.territorial_demands.erase(
		system_id
	)

	if relation.event_history.size() > 20:
		relation.event_history.pop_front()
		
func _transfer_territorial_system(
	winner: CivilizationData,
	loser: CivilizationData,
	system_id: int
) -> void:
	if winner == null:
		return

	if loser == null:
		return

	if system_id < 0:
		return

	var loser_systems: Array = (
		_civilization_controlled_system_ids.get(
			loser.global_id,
			[]
		)
	)

	var winner_systems: Array = (
		_civilization_controlled_system_ids.get(
			winner.global_id,
			[]
		)
	)

	if not loser_systems.has(system_id):
		return

	if not winner_systems.has(system_id):
		winner_systems.append(
			system_id
		)

	_civilization_controlled_system_ids[
		winner.global_id
	] = winner_systems

	loser_systems.erase(
		system_id
	)

	_civilization_controlled_system_ids[
		loser.global_id
	] = loser_systems

	var planets: Array[PlanetData] = (
		_system_planets.get(
			system_id,
			[]
		)
	)

	for planet in planets:
		if planet == null:
			continue

		if planet.colony_owner_id != loser.global_id:
			continue

		var transferred_colony: ColonyData = (
			loser.remove_colony(
				planet.global_id
			)
		)

		if transferred_colony == null:
			continue

		winner.take_over_colony(
			transferred_colony
		)

		planet.colony_owner_id = (
			winner.global_id
		)

	_log_event(
		"[Territoire] "
		+ winner.name
		+ " prend le contrôle du système #"
		+ str(system_id)
		+ " à "
		+ loser.name,
		[winner.global_id, loser.global_id]
	)
	
func _process_territorial_demands() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			continue

		if relation.territorial_demands.is_empty():
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		var demands: Array = (
			relation.territorial_demands.keys()
		)

		for system_id_value in demands:
			var system_id: int = (
				int(system_id_value)
			)

			var demanding_id: int = (
				int(
					relation.territorial_demands[
						system_id_value
					]
				)
			)

			var demanding_civilization: CivilizationData = null
			var target_civilization: CivilizationData = null

			if demanding_id == civilization_a.global_id:
				demanding_civilization = civilization_a
				target_civilization = civilization_b
			elif demanding_id == civilization_b.global_id:
				demanding_civilization = civilization_b
				target_civilization = civilization_a
			else:
				relation.territorial_demands.erase(
					system_id_value
				)
				continue

			_resolve_territorial_demand(
				relation,
				demanding_civilization,
				target_civilization,
				system_id
			)

func _get_system_civilization_owners(
	system_id: int
) -> Array[CivilizationData]:
	var result: Array[CivilizationData] = []

	var planets: Array[PlanetData] = (
		_system_planets.get(
			system_id,
			[]
		)
	)

	for planet in planets:
		if planet == null:
			continue

		var owner_id: int = -1

		if planet.civilization != null:
			owner_id = (
				planet.civilization.global_id
			)
		elif planet.colony_owner_id != -1:
			owner_id = (
				planet.colony_owner_id
			)

		if owner_id < 0:
			continue

		var civilization: CivilizationData = (
			_civilizations.get(
				owner_id,
				null
			)
		)

		if civilization == null:
			continue

		if result.has(civilization):
			continue

		result.append(
			civilization
		)

	return result
	
func _civilization_has_presence_in_system(
	civilization_id: int,
	system_id: int
) -> bool:
	if civilization_id < 0:
		return false

	if system_id < 0:
		return false

	var planets: Array[PlanetData] = (
		_system_planets.get(
			system_id,
			[]
		)
	)

	for planet in planets:
		if planet == null:
			continue

		if planet.civilization != null:
			if (
				planet.civilization.global_id
				== civilization_id
			):
				return true

		if (
			planet.colony_owner_id
			== civilization_id
		):
			return true

	return false

func _update_claims_after_conquest(
	winner: CivilizationData,
	loser: CivilizationData,
	system_id: int
) -> void:
	if winner == null:
		return

	if loser == null:
		return

	if system_id < 0:
		return

	if not _civilization_territorial_claims.has(
		winner.global_id
	):
		_civilization_territorial_claims[
			winner.global_id
		] = {}

	if not _civilization_territorial_claims.has(
		loser.global_id
	):
		_civilization_territorial_claims[
			loser.global_id
		] = {}

	var winner_claims: Dictionary = (
		_civilization_territorial_claims[
			winner.global_id
		]
	)

	var loser_claims: Dictionary = (
		_civilization_territorial_claims[
			loser.global_id
		]
	)

	# Le vainqueur possède maintenant réellement le système.
	winner_claims[system_id] = 100.0

	# Le perdant ne revendique plus son ancien territoire.
	loser_claims.erase(
		system_id
	)

	# Les revendications du vainqueur sont renforcées
	# autour du nouveau territoire.
	var controlled_systems: Array = (
		_civilization_controlled_system_ids.get(
			winner.global_id,
			[]
		)
	)

	var interaction_range: float = (
		winner.get_interaction_range()
	)

	if interaction_range <= 0.0:
		return

	var conquered_position: Vector2 = (
		_system_positions.get(
			system_id,
			Vector2.INF
		)
	)

	if conquered_position == Vector2.INF:
		return

	for system_value in _systems.keys():
		var neighbor_system_id: int = (
			int(system_value)
		)

		if controlled_systems.has(
			neighbor_system_id
		):
			continue

		var neighbor_position: Vector2 = (
			_system_positions.get(
				neighbor_system_id,
				Vector2.INF
			)
		)

		if neighbor_position == Vector2.INF:
			continue

		var distance: float = (
			conquered_position.distance_to(
				neighbor_position
			)
		)

		if distance > interaction_range:
			continue

		var proximity: float = (
			1.0
			- distance / interaction_range
		)

		proximity = clamp(
			proximity,
			0.0,
			1.0
		)

		var existing_claim: float = (
			float(
				winner_claims.get(
					neighbor_system_id,
					0.0
				)
			)
		)

		var new_claim: float = max(
			existing_claim,
			proximity * 70.0
		)

		winner_claims[
			neighbor_system_id
		] = clamp(
			new_claim,
			0.0,
			100.0
		)

func _civilization_has_homeworld_in_system(
	civilization_id: int,
	system_id: int
) -> bool:
	if civilization_id < 0:
		return false

	if system_id < 0:
		return false

	var planets: Array[PlanetData] = (
		_system_planets.get(
			system_id,
			[]
		)
	)

	for planet in planets:
		if planet == null:
			continue

		if planet.civilization == null:
			continue

		if (
			planet.civilization.global_id
			== civilization_id
		):
			return true

	return false
	
func _civilization_controls_system(
	civilization_id: int,
	system_id: int
) -> bool:
	if civilization_id < 0:
		return false

	if system_id < 0:
		return false

	var controlled_systems: Array = (
		_civilization_controlled_system_ids.get(
			civilization_id,
			[]
		)
	)

	if controlled_systems.has(system_id):
		return true

	# Une civilisation qui possède son monde d'origine
	# contrôle naturellement son système.
	if _civilization_has_homeworld_in_system(
		civilization_id,
		system_id
	):
		return true

	return false

func _calculate_civilization_system_influence(
	civilization: CivilizationData,
	system_id: int
) -> float:
	if civilization == null:
		return 0.0

	if system_id < 0:
		return 0.0

	var target_position: Vector2 = (
		_system_positions.get(
			system_id,
			Vector2.INF
		)
	)

	if target_position == Vector2.INF:
		return 0.0

	var controlled_systems: Array = (
		_civilization_controlled_system_ids.get(
			civilization.global_id,
			[]
		)
	)

	if controlled_systems.is_empty():
		return 0.0

	var interaction_range: float = (
		civilization.get_interaction_range()
	)

	if interaction_range <= 0.0:
		return 0.0

	var closest_distance: float = INF

	for system_value in controlled_systems:
		var controlled_system_id: int = (
			int(system_value)
		)

		var controlled_position: Vector2 = (
			_system_positions.get(
				controlled_system_id,
				Vector2.INF
			)
		)

		if controlled_position == Vector2.INF:
			continue

		var distance: float = (
			controlled_position.distance_to(
				target_position
			)
		)

		if distance < closest_distance:
			closest_distance = distance

	if closest_distance == INF:
		return 0.0

	var proximity: float = (
		1.0
		- closest_distance / interaction_range
	)

	proximity = clamp(
		proximity,
		0.0,
		1.0
	)

	var influence: float = (
		proximity * 35.0
	)

	# -------------------------------------------------
	# PUISSANCE GENERALE
	# -------------------------------------------------

	influence += (
		civilization.technology * 0.10
	)

	influence += (
		civilization.military_power * 0.10
	)

	influence += (
		civilization.diplomacy * 0.05
	)

	influence += (
		civilization.expansionism * 0.05
	)

	# -------------------------------------------------
	# ECONOMIE
	# -------------------------------------------------

	influence += (
		civilization.economy * 0.05
	)

	influence += (
		civilization.trade_income * 0.10
	)

	influence += (
		civilization.colony_income * 0.05
	)

	# -------------------------------------------------
	# COLONIES
	# -------------------------------------------------

	var colony_count: int = 0
	var colony_population: int = 0
	var colony_production: float = 0.0

	for colony in civilization.colonies:
		if colony == null:
			continue

		var colony_system_value = (
			_planet_system_ids.get(
				colony.planet_id,
				null
			)
		)

		if colony_system_value == null:
			continue

		if int(colony_system_value) != system_id:
			continue

		colony_count += 1

		var stability_factor: float = clamp(
			colony.stability / 100.0,
			0.25,
			1.0
		)

		colony_population += int(
			float(colony.population)
			* stability_factor
		)

		colony_production += (
			colony.production
			* stability_factor
		)

		colony_production += (
			colony.production
		)

	if colony_count > 0:
		influence += (
			float(colony_count) * 10.0
		)

		influence += min(
			float(colony_population) / 100000000.0,
			10.0
		)

		influence += min(
			colony_production * 0.10,
			10.0
		)

	# -------------------------------------------------
	# MONDE D'ORIGINE
	# -------------------------------------------------

	if _civilization_has_homeworld_in_system(
		civilization.global_id,
		system_id
	):
		influence += 40.0

	# -------------------------------------------------
	# ALLIANCES
	# -------------------------------------------------

	var ally_count: int = (
		_count_civilization_allies(
			civilization.global_id
		)
	)

	influence += (
		float(ally_count) * 3.0
	)

	# -------------------------------------------------
	# SYSTEME DISPUTE
	# -------------------------------------------------

	if _contested_systems.has(system_id):
		influence *= 0.95

	return clamp(
		influence,
		0.0,
		100.0
	)

func _update_civilization_system_influence() -> void:
	_civilization_system_influence.clear()
	_contested_systems.clear()

	if _systems.is_empty():
		return

	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.is_empty():
		return

	for civilization in civilizations:
		if civilization == null:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		var controlled_systems: Array = (
			_civilization_controlled_system_ids.get(
				civilization_id,
				[]
			)
		)

		if controlled_systems.is_empty():
			continue

		var interaction_range: float = (
			civilization.get_interaction_range()
		)

		if interaction_range <= 0.0:
			continue

		var candidate_distances: Dictionary = (
			_civilization_system_closest_distances.get(
				civilization_id,
				{}
			)
		)

		if candidate_distances.is_empty():
			continue

		var ally_count: int = (
			_count_civilization_allies(
				civilization_id
			)
		)

		var homeworld_system_id: int = -1

		var homeworld_system_value = (
			_planet_system_ids.get(
				civilization.home_planet_id,
				null
			)
		)

		if homeworld_system_value != null:
			homeworld_system_id = int(
				homeworld_system_value
			)

		var colony_stats_by_system: Dictionary = {}

		for colony in civilization.colonies:
			if colony == null:
				continue

			var colony_system_value = (
				_planet_system_ids.get(
					colony.planet_id,
					null
				)
			)

			if colony_system_value == null:
				continue

			var colony_system_id: int = (
				int(colony_system_value)
			)

			var stability_factor: float = (
				colony.stability / 100.0
			)

			if stability_factor < 0.25:
				stability_factor = 0.25
			elif stability_factor > 1.0:
				stability_factor = 1.0

			var colony_population: int = int(
				float(colony.population)
				* stability_factor
			)

			var colony_production: float = (
				colony.production
				* stability_factor
			)

			var stats: Dictionary = (
				colony_stats_by_system.get(
					colony_system_id,
					{}
				)
			)

			stats["count"] = (
				int(stats.get("count", 0))
				+ 1
			)

			stats["population"] = (
				int(stats.get("population", 0))
				+ colony_population
			)

			stats["production"] = (
				float(stats.get("production", 0.0))
				+ colony_production
			)

			colony_stats_by_system[
				colony_system_id
			] = stats

		var base_influence: float = (
			civilization.technology * 0.10
			+ civilization.military_power * 0.10
			+ civilization.diplomacy * 0.05
			+ civilization.expansionism * 0.05
			+ civilization.economy * 0.05
			+ civilization.trade_income * 0.10
			+ civilization.colony_income * 0.05
			+ float(ally_count) * 3.0
		)

		var inverse_interaction_range: float = (
			1.0 / interaction_range
		)

		for system_value in candidate_distances.keys():
			var system_id: int = (
				int(system_value)
			)

			var closest_distance_squared: float = (
				float(
					candidate_distances[
						system_value
					]
				)
			)

			var closest_distance: float = sqrt(
				closest_distance_squared
			)

			var proximity: float = (
				1.0
				- closest_distance
				* inverse_interaction_range
			)

			if proximity < 0.0:
				proximity = 0.0
			elif proximity > 1.0:
				proximity = 1.0

			var influence: float = (
				proximity * 35.0
				+ base_influence
			)

			var colony_stats = (
				colony_stats_by_system.get(
					system_id,
					null
				)
			)

			if colony_stats != null:
				var colony_count: int = int(
					colony_stats["count"]
				)

				var colony_population: int = int(
					colony_stats["population"]
				)

				var colony_production: float = (
					float(
						colony_stats["production"]
					)
				)

				influence += (
					float(colony_count) * 10.0
				)

				influence += min(
					float(colony_population)
					/ 100000000.0,
					10.0
				)

				influence += min(
					colony_production * 0.10,
					10.0
				)

			if system_id == homeworld_system_id:
				influence += 40.0

			if influence > 100.0:
				influence = 100.0
			elif influence < 0.0:
				influence = 0.0

			if influence < 5.0:
				continue

			var influences = (
				_civilization_system_influence.get(
					system_id,
					null
				)
			)

			if influences == null:
				influences = {}

				_civilization_system_influence[
					system_id
				] = influences

			influences[
				civilization_id
			] = influence

	# Détection des systèmes contestés.
	for system_value in _civilization_system_influence.keys():
		var system_id: int = (
			int(system_value)
		)

		var influences: Dictionary = (
			_civilization_system_influence[
				system_value
			]
		)

		if influences.size() < 2:
			continue

		var strongest_value: float = -1.0
		var second_value: float = -1.0

		for influence_value in influences.values():
			var influence: float = (
				float(influence_value)
			)

			if influence > strongest_value:
				second_value = strongest_value
				strongest_value = influence
			elif influence > second_value:
				second_value = influence

		if second_value < 0.0:
			continue

		var influence_difference: float = (
			strongest_value
			- second_value
		)

		if influence_difference < 15.0:
			_contested_systems[
				system_id
			] = true

func _evaluate_contested_system_tensions() -> void:
	for system_value in _contested_systems.keys():
		var system_id: int = int(system_value)

		var influences: Dictionary = (
			_civilization_system_influence.get(
				system_id,
				{}
			)
		)

		if influences.size() < 2:
			continue

		var first_civilization: CivilizationData = null
		var second_civilization: CivilizationData = null

		var first_influence: float = 0.0
		var second_influence: float = 0.0

		for civilization_id_value in influences.keys():
			var influence: float = float(
				influences[civilization_id_value]
			)

			if influence < 20.0:
				continue

			var civilization_id: int = (
				int(civilization_id_value)
			)

			var civilization: CivilizationData = (
				_civilizations.get(
					civilization_id,
					null
				)
			)

			if civilization == null:
				continue

			if influence > first_influence:
				second_civilization = first_civilization
				second_influence = first_influence

				first_civilization = civilization
				first_influence = influence

			elif influence > second_influence:
				second_civilization = civilization
				second_influence = influence

		if first_civilization == null:
			continue

		if second_civilization == null:
			continue

		var relation_key: String = (
			_get_relation_key(
				first_civilization.global_id,
				second_civilization.global_id
			)
		)

		if relation_key.is_empty():
			continue

		var relation: RelationData = (
			_relations.get(
				relation_key,
				null
			)
		)

		if relation == null:
			continue

		if relation.at_war:
			continue

		var influence_total: float = (
			first_influence
			+ second_influence
		)

		if influence_total <= 0.0:
			continue

		var influence_difference: float = (
			abs(
				first_influence
				- second_influence
			)
		)

		var competition: float = (
			1.0
			- influence_difference
			/ influence_total
		)

		if competition < 0.0:
			competition = 0.0
		elif competition > 1.0:
			competition = 1.0

		var expansionism_sum: float = (
			first_civilization.expansionism
			+ second_civilization.expansionism
		)

		var militarism_sum: float = (
			first_civilization.militarism
			+ second_civilization.militarism
		)

		var tension: float = (
			competition * 0.50
		)

		tension += (
			expansionism_sum
			* 0.0015
		)

		tension += (
			militarism_sum
			* 0.001
		)

		if tension <= 0.0:
			continue

		relation.relation -= tension

		if relation.relation < -100.0:
			relation.relation = -100.0
		elif relation.relation > 100.0:
			relation.relation = 100.0

		if tension < 0.5:
			continue

		var event_message: String = (
			"Année "
			+ str(current_year)
			+ " : tensions territoriales autour du système #"
			+ str(system_id)
			+ "."
		)

		if (
			relation.event_history.is_empty()
			or relation.event_history.back()
			!= event_message
		):
			relation.event_history.append(
				event_message
			)

			if relation.event_history.size() > 20:
				relation.event_history.pop_front()

func _count_civilization_allies(
	civilization_id: int
) -> int:
	if civilization_id < 0:
		return 0

	var allies: Array = (
		_civilization_allies.get(
			civilization_id,
			[]
		)
	)

	return allies.size()

func _evaluate_peaceful_integrations() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.size() < 2:
		return

	for losing_civilization in civilizations:
		if losing_civilization == null:
			continue

		if losing_civilization.colonies.is_empty():
			continue

		for colony in losing_civilization.colonies:
			if colony == null:
				continue

			var system_value = (
				_planet_system_ids.get(
					colony.planet_id,
					null
				)
			)

			if system_value == null:
				continue

			var system_id: int = (
				int(system_value)
			)

			var influences: Dictionary = (
				_civilization_system_influence.get(
					system_id,
					{}
				)
			)

			if influences.is_empty():
				continue

			var strongest_civilization: CivilizationData = null
			var strongest_influence: float = 0.0

			for civilization_id_value in influences.keys():
				var civilization_id: int = (
					int(civilization_id_value)
				)

				if civilization_id == (
					losing_civilization.global_id
				):
					continue

				var influence: float = (
					float(
						influences[
							civilization_id_value
						]
					)
				)

				if influence <= strongest_influence:
					continue

				var candidate: CivilizationData = (
					get_civilization(
						civilization_id
					)
				)

				if candidate == null:
					continue

				strongest_influence = influence
				strongest_civilization = candidate

			if strongest_civilization == null:
				continue

			if strongest_civilization == losing_civilization:
				continue

			if strongest_influence < 65.0:
				continue

			var relation_key: String = (
				_get_relation_key(
					strongest_civilization.global_id,
					losing_civilization.global_id
				)
			)

			if relation_key.is_empty():
				continue

			var relation: RelationData = (
				_relations.get(
					relation_key,
					null
				)
			)

			if relation == null:
				continue

			if relation.at_war:
				continue

			if relation.relation < 30.0:
				continue

			if relation.trust < 40.0:
				continue

			var pressure: float = (
				_calculate_integration_pressure(
					strongest_civilization,
					losing_civilization,
					colony,
					system_id
				)
			)

			if pressure < 50.0:
				continue

			var rng := RandomNumberGenerator.new()

			rng.seed = (
				colony.seed
				+ current_year * 7919
				+ strongest_civilization.global_id * 313
				+ losing_civilization.global_id * 997
			)

			var chance: float = (
				(pressure - 50.0)
				* 0.0008
			)

			chance = clamp(
				chance,
				0.0,
				0.04
			)

			if rng.randf() > chance:
				continue

			_integrate_colony_peacefully(
				strongest_civilization,
				losing_civilization,
				colony,
				relation
			)

			break

func _integrate_colony_peacefully(
	receiving_civilization: CivilizationData,
	losing_civilization: CivilizationData,
	colony: ColonyData,
	relation: RelationData
) -> void:
	if receiving_civilization == null:
		return

	if losing_civilization == null:
		return

	if colony == null:
		return

	if relation == null:
		return

	var planet_id: int = (
		colony.planet_id
	)

	var planet: PlanetData = (
		_planets.get(
			planet_id,
			null
		)
	)

	if planet == null:
		return

	losing_civilization.remove_colony(
		planet_id
	)

	receiving_civilization.take_over_colony(
		colony
	)

	planet.colony_owner_id = (
		receiving_civilization.global_id
	)

	var system_value = (
		_planet_system_ids.get(
			planet_id,
			null
		)
	)

	if system_value != null:
		var system_id: int = (
			int(system_value)
		)

		if not _civilization_controlled_system_ids.has(
			receiving_civilization.global_id
		):
			_civilization_controlled_system_ids[
				receiving_civilization.global_id
			] = []

		var receiving_systems: Array = (
			_civilization_controlled_system_ids[
				receiving_civilization.global_id
			]
		)

		if not receiving_systems.has(
			system_id
		):
			receiving_systems.append(
				system_id
			)

		relation.relation += 8.0
		relation.trust += 5.0

		relation.relation = clamp(
			relation.relation,
			-100.0,
			100.0
		)

		relation.trust = clamp(
			relation.trust,
			0.0,
			100.0
		)

		relation.event_history.append(
			"Année "
			+ str(current_year)
			+ " : transfert pacifique de la colonie #"
			+ str(planet_id)
			+ " vers "
			+ receiving_civilization.name
			+ "."
		)

		if relation.event_history.size() > 20:
			relation.event_history.pop_front()

	_log_event(
		"[Intégration] "
		+ receiving_civilization.name
		+ " intègre pacifiquement la colonie #"
		+ str(planet_id)
		+ " de "
		+ losing_civilization.name,
		[
			receiving_civilization.global_id,
			losing_civilization.global_id,
		]
	)

func _calculate_integration_pressure(
	receiving_civilization: CivilizationData,
	losing_civilization: CivilizationData,
	colony: ColonyData,
	system_id: int
) -> float:
	if receiving_civilization == null:
		return 0.0

	if losing_civilization == null:
		return 0.0

	if colony == null:
		return 0.0

	if system_id < 0:
		return 0.0

	var influences: Dictionary = (
		_civilization_system_influence.get(
			system_id,
			{}
		)
	)

	var receiving_influence: float = (
		float(
			influences.get(
				receiving_civilization.global_id,
				0.0
			)
		)
	)

	var losing_influence: float = (
		float(
			influences.get(
				losing_civilization.global_id,
				0.0
			)
		)
	)

	var pressure: float = 0.0

	# Supériorité régionale.
	var influence_difference: float = (
		receiving_influence
		- losing_influence
	)

	pressure += (
		influence_difference
		* 0.50
	)

	# Stabilité de la colonie.
	# Une colonie stable résiste davantage à un changement,
	# mais une colonie très instable est plus facile à attirer.
	pressure += (
		(100.0 - colony.stability)
		* 0.25
	)

	# Diplomatie du pouvoir intégrateur.
	pressure += (
		receiving_civilization.diplomacy
		* 0.20
	)

	# Commerce.
	pressure += (
		receiving_civilization.commerce
		* 0.10
	)

	# Isolement du pouvoir actuel.
	pressure += (
		losing_civilization.isolationism
		* 0.10
	)

	# Une colonie très loyale et très développée résiste
	# davantage à l'intégration.
	pressure -= (
		colony.development
		* 0.15
	)

	return clamp(
		pressure,
		0.0,
		100.0
	)

func _apply_economic_dependence_effects() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		var dependence_a: float = (
			relation.economic_dependence_a
		)

		var dependence_b: float = (
			relation.economic_dependence_b
		)

		if dependence_a <= 0.0 \
		and dependence_b <= 0.0:
			continue

		var disruption_a: float = 0.0
		var disruption_b: float = 0.0

		if relation.at_war:
			disruption_a = (
				dependence_a * 0.08
			)

			disruption_b = (
				dependence_b * 0.08
			)
		elif relation.trade <= 0.0:
			disruption_a = (
				dependence_a * 0.03
			)

			disruption_b = (
				dependence_b * 0.03
			)
		else:
			continue

		civilization_a.economy = max(
			civilization_a.economy
			- disruption_a,
			1.0
		)

		civilization_b.economy = max(
			civilization_b.economy
			- disruption_b,
			1.0
		)

		civilization_a.military_power = max(
			civilization_a.military_power
			- disruption_a * 0.25,
			0.0
		)

		civilization_b.military_power = max(
			civilization_b.military_power
			- disruption_b * 0.25,
			0.0
		)

func _evaluate_economic_sanctions() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			relation.sanctions_a = false
			relation.sanctions_b = false
			relation.sanctions_level_a = 0.0
			relation.sanctions_level_b = 0.0
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		var wants_a: bool = (
			civilization_a.wants_to_sanction(
				civilization_b,
				relation
			)
		)

		var wants_b: bool = (
			civilization_b.wants_to_sanction(
				civilization_a,
				relation
			)
		)

		if wants_a:
			relation.sanctions_a = true
			relation.sanctions_level_a = min(
				relation.sanctions_level_a + 10.0,
				100.0
			)
		else:
			relation.sanctions_level_a = max(
				relation.sanctions_level_a - 5.0,
				0.0
			)

			if relation.sanctions_level_a <= 0.0:
				relation.sanctions_a = false

		if wants_b:
			relation.sanctions_b = true
			relation.sanctions_level_b = min(
				relation.sanctions_level_b + 10.0,
				100.0
			)
		else:
			relation.sanctions_level_b = max(
				relation.sanctions_level_b - 5.0,
				0.0
			)

			if relation.sanctions_level_b <= 0.0:
				relation.sanctions_b = false

		if relation.sanctions_a:
			relation.trade = max(
				relation.trade
				- relation.sanctions_level_a * 0.02,
				0.0
			)

		if relation.sanctions_b:
			relation.trade = max(
				relation.trade
				- relation.sanctions_level_b * 0.02,
				0.0
			)

func _evaluate_trade_recovery() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.is_empty():
		return

	for civilization in civilizations:
		if civilization == null:
			continue

		var recovery_rate: float = (
			civilization.get_trade_recovery_rate()
		)

		if recovery_rate <= 0.0:
			continue

		var best_relation: RelationData = null
		var best_score: float = 0.0

		for relation in _relations.values():
			if relation == null:
				continue

			if relation.at_war:
				continue

			var other_id: int = -1

			if relation.civilization_a_id == (
				civilization.global_id
			):
				other_id = relation.civilization_b_id
			elif relation.civilization_b_id == (
				civilization.global_id
			):
				other_id = relation.civilization_a_id
			else:
				continue

			var other_civilization: CivilizationData = (
				get_civilization(
					other_id
				)
			)

			if other_civilization == null:
				continue

			if not civilization.knows_civilization(
				other_civilization.global_id
			):
				continue

			if not other_civilization.knows_civilization(
				civilization.global_id
			):
				continue

			if relation.relation < 0.0:
				continue

			if relation.trade >= 80.0:
				continue

			var score: float = (
				relation.relation * 0.40
			)

			score += (
				relation.trust * 0.30
			)

			score += (
				other_civilization.commerce * 0.15
			)

			score += (
				other_civilization.diplomacy * 0.10
			)

			score += (
				other_civilization.economy * 0.05
			)

			if relation.sanctions_a \
			or relation.sanctions_b:
				score -= 30.0

			if score <= best_score:
				continue

			best_score = score
			best_relation = relation

		if best_relation == null:
			continue

		var recovery_amount: float = (
			recovery_rate
			* 0.01
		)

		best_relation.trade = min(
			best_relation.trade
			+ recovery_amount,
			100.0
		)

func _apply_trade_network_effects() -> void:
	for civilization in _get_all_civilizations():
		if civilization == null:
			continue

		var network_strength: float = (
			civilization.trade_network_strength
		)

		if network_strength <= 0.0:
			continue

		var economic_bonus: float = (
			network_strength * 0.002
		)

		var technology_bonus: float = (
			network_strength * 0.001
		)

		civilization.economy = clamp(
			civilization.economy
			+ economic_bonus,
			1.0,
			100.0
		)

		civilization.technology = clamp(
			civilization.technology
			+ technology_bonus,
			1.0,
			100.0
		)

func _evaluate_trade_network_alliances() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			continue

		if relation.alliance:
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		if not civilization_a.knows_civilization(
			civilization_b.global_id
		):
			continue

		if not civilization_b.knows_civilization(
			civilization_a.global_id
		):
			continue

		if relation.relation < 55.0:
			continue

		if relation.trust < 60.0:
			continue

		if relation.trade < 35.0:
			continue

		var network_a: float = (
			civilization_a.trade_network_strength
		)

		var network_b: float = (
			civilization_b.trade_network_strength
		)

		var network_strength: float = (
			network_a + network_b
		) * 0.5

		var diplomacy_factor: float = (
			(
				civilization_a.diplomacy
				+ civilization_b.diplomacy
			) * 0.005
		)

		var commerce_factor: float = (
			(
				civilization_a.commerce
				+ civilization_b.commerce
			) * 0.003
		)

		var compatibility: float = (
			network_strength * 0.25
		)

		compatibility += (
			relation.relation * 0.25
		)

		compatibility += (
			relation.trust * 0.20
		)

		compatibility += (
			relation.trade * 0.20
		)

		compatibility += diplomacy_factor
		compatibility += commerce_factor

		compatibility = clamp(
			compatibility,
			0.0,
			100.0
		)

		if compatibility < 65.0:
			continue

		if not relation.can_form_alliance():
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = (
			civilization_a.seed
			+ civilization_b.seed
			+ current_year * 7919
		)

		var chance: float = (
			compatibility - 65.0
		) * 0.002

		chance = clamp(
			chance,
			0.0,
			0.08
		)

		if rng.randf() > chance:
			continue

		relation.alliance = true

		relation.event_history.append(
			"Année "
			+ str(current_year)
			+ " : alliance commerciale et diplomatique entre "
			+ civilization_a.name
			+ " et "
			+ civilization_b.name
			+ "."
		)

		if relation.event_history.size() > 20:
			relation.event_history.pop_front()

		_civilization_allies_dirty = true

		print(
			"[Alliance commerciale] ",
			civilization_a.name,
			" et ",
			civilization_b.name,
			" forment une alliance."
		)

func _evaluate_allied_interventions() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if not relation.at_war:
			continue

		var civilization_a: CivilizationData = (
			get_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			get_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		_evaluate_allied_support_for_war(
			civilization_a,
			civilization_b
		)

		_evaluate_allied_support_for_war(
			civilization_b,
			civilization_a
		)

func _evaluate_allied_support_for_war(
	ally_of_attacker: CivilizationData,
	enemy: CivilizationData
) -> void:
	if ally_of_attacker == null:
		return

	if enemy == null:
		return

	var allies: Array = (
		_civilization_allies.get(
			ally_of_attacker.global_id,
			[]
		)
	)

	if allies.is_empty():
		return

	for ally_id_value in allies:
		var ally_id: int = (
			int(ally_id_value)
		)

		var ally: CivilizationData = (
			get_civilization(
				ally_id
			)
		)

		if ally == null:
			continue

		if ally == enemy:
			continue

		var ally_relation_key: String = (
			_get_relation_key(
				ally.global_id,
				ally_of_attacker.global_id
			)
		)

		if ally_relation_key.is_empty():
			continue

		var ally_relation: RelationData = (
			_relations.get(
				ally_relation_key,
				null
			)
		)

		if ally_relation == null:
			continue

		if not ally_relation.alliance:
			continue

		if ally_relation.at_war:
			continue

		if not ally.knows_civilization(
			enemy.global_id
		):
			continue

		if not ally.wants_to_support_ally(
			ally_of_attacker,
			enemy,
			ally_relation
		):
			continue

		var enemy_relation_key: String = (
			_get_relation_key(
				ally.global_id,
				enemy.global_id
			)
		)

		if enemy_relation_key.is_empty():
			continue

		var enemy_relation: RelationData = (
			_relations.get(
				enemy_relation_key,
				null
			)
		)

		if enemy_relation == null:
			enemy_relation = _create_relation(
				ally,
				enemy
			)

		if enemy_relation == null:
			continue

		if enemy_relation.at_war:
			continue

		enemy_relation.at_war = true
		enemy_relation.war_years = 0
		enemy_relation.war_score = 0.0
		enemy_relation.last_war_winner = -1
		enemy_relation.war_ended_year = -1
		enemy_relation.alliance = false

		enemy_relation.relation = min(
			enemy_relation.relation,
			-60.0
		)

		enemy_relation.trust = min(
			enemy_relation.trust,
			20.0
		)

		enemy_relation.event_history.append(
			"Année "
			+ str(current_year)
			+ " : "
			+ ally.name
			+ " intervient aux côtés de "
			+ ally_of_attacker.name
			+ " contre "
			+ enemy.name
			+ "."
		)

		if enemy_relation.event_history.size() > 20:
			enemy_relation.event_history.pop_front()

		print(
			"[Intervention] ",
			ally.name,
			" rejoint la guerre aux côtés de ",
			ally_of_attacker.name,
			" contre ",
			enemy.name
		)

func _update_trade_networks() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	for civilization in civilizations:
		if civilization == null:
			continue

		var network_strength: float = 0.0
		var active_partners: int = 0

		for relation in _relations.values():
			if relation == null:
				continue

			if relation.trade < 30.0:
				continue

			if relation.civilization_a_id != (
				civilization.global_id
			) and relation.civilization_b_id != (
				civilization.global_id
			):
				continue

			active_partners += 1

			network_strength += (
				relation.trade * 0.25
			)

		network_strength += (
			float(active_partners) * 5.0
		)

		civilization.trade_network_strength = clamp(
			network_strength,
			0.0,
			100.0
		)

func _calculate_war_coalition_power(
	civilization: CivilizationData,
	enemy: CivilizationData
) -> float:
	if civilization == null:
		return 0.0

	if enemy == null:
		return 0.0

	var total_power: float = (
		civilization.military_power
	)

	var allies: Array = (
		_civilization_allies.get(
			civilization.global_id,
			[]
		)
	)

	for ally_id_value in allies:
		var ally_id: int = (
			int(ally_id_value)
		)

		var ally: CivilizationData = (
			get_civilization(
				ally_id
			)
		)

		if ally == null:
			continue

		if ally == enemy:
			continue

		var relation_key: String = (
			_get_relation_key(
				ally.global_id,
				enemy.global_id
			)
		)

		if relation_key.is_empty():
			continue

		var relation: RelationData = (
			_relations.get(
				relation_key,
				null
			)
		)

		if relation == null:
			continue

		if not relation.at_war:
			continue

		total_power += (
			ally.military_power
			* 0.75
		)

	return max(
		total_power,
		0.0
	)

func _calculate_colony_defense_strength(
	civilization: CivilizationData,
	colony: ColonyData
) -> float:
	if civilization == null:
		return 0.0

	if colony == null:
		return 0.0

	var system_value = (
		_planet_system_ids.get(
			colony.planet_id,
			null
		)
	)

	if system_value == null:
		return 0.0

	var system_id: int = (
		int(system_value)
	)

	var position: Vector2 = (
		_system_positions.get(
			system_id,
			Vector2.INF
		)
	)

	if position == Vector2.INF:
		return 0.0

	var controlled_systems: Array = (
		_civilization_controlled_system_ids.get(
			civilization.global_id,
			[]
		)
	)

	if controlled_systems.is_empty():
		return 0.0

	var closest_distance: float = INF

	for controlled_system_value in controlled_systems:
		var controlled_system_id: int = (
			int(controlled_system_value)
		)

		if controlled_system_id == system_id:
			continue

		var controlled_position: Vector2 = (
			_system_positions.get(
				controlled_system_id,
				Vector2.INF
			)
		)

		if controlled_position == Vector2.INF:
			continue

		var distance: float = (
			position.distance_to(
				controlled_position
			)
		)

		if distance < closest_distance:
			closest_distance = distance

	var defense: float = 0.0

	defense += (
		colony.stability * 0.35
	)

	defense += (
		colony.development * 0.25
	)

	defense += min(
		float(colony.population) / 10000000.0,
		20.0
	)

	defense += (
		civilization.military_power * 0.15
	)

	defense += (
		civilization.technology * 0.10
	)

	if closest_distance != INF:
		var proximity_factor: float = clamp(
			1.0
			- closest_distance / 500.0,
			0.0,
			1.0
		)

		defense += (
			proximity_factor * 20.0
		)
	else:
		defense += 10.0

	if _civilization_has_homeworld_in_system(
		civilization.global_id,
		system_id
	):
		defense += 30.0

	if _contested_systems.has(system_id):
		defense += 10.0

	return clamp(
		defense,
		0.0,
		100.0
	)
	
func _get_best_defended_colony(
	civilization: CivilizationData
) -> ColonyData:
	if civilization == null:
		return null

	if civilization.colonies.is_empty():
		return null

	var best_colony: ColonyData = null
	var best_defense: float = -INF

	for colony in civilization.colonies:
		if colony == null:
			continue

		var defense: float = (
			_calculate_colony_defense_strength(
				civilization,
				colony
			)
		)

		if defense <= best_defense:
			continue

		best_defense = defense
		best_colony = colony

	return best_colony

func _rebuild_system_spatial_grid() -> void:
	_system_spatial_grid.clear()

	for system_value in _systems.keys():
		var system_id: int = int(system_value)

		var position: Vector2 = (
			_system_positions.get(
				system_id,
				Vector2.INF
			)
		)

		if position == Vector2.INF:
			continue

		var cell_x: int = floori(
			position.x / SYSTEM_SPATIAL_CELL_SIZE
		)

		var cell_y: int = floori(
			position.y / SYSTEM_SPATIAL_CELL_SIZE
		)

		var cell_key: Vector2i = Vector2i(
			cell_x,
			cell_y
		)

		if not _system_spatial_grid.has(
			cell_key
		):
			_system_spatial_grid[cell_key] = []

		_system_spatial_grid[cell_key].append(
			system_id
		)

func _rebuild_exploration_frontier(
	civilization: CivilizationData,
	exploration_range: float
) -> void:
	if civilization == null:
		return

	if exploration_range <= 0.0:
		return

	var civilization_id: int = (
		civilization.global_id
	)

	var frontier: Dictionary = {}

	var interaction_range_squared: float = (
		exploration_range
		* exploration_range
	)

	var cell_radius: int = ceili(
		exploration_range
		/ SYSTEM_SPATIAL_CELL_SIZE
	)

	var explored_lookup: Dictionary = {}

	for system_id in civilization.explored_system_ids:
		explored_lookup[
			int(system_id)
		] = true

	for known_system_id in civilization.explored_system_ids:
		var origin_position: Vector2 = (
			_system_positions.get(
				known_system_id,
				Vector2.INF
			)
		)

		if origin_position == Vector2.INF:
			continue

		var center_x: int = floori(
			origin_position.x
			/ SYSTEM_SPATIAL_CELL_SIZE
		)

		var center_y: int = floori(
			origin_position.y
			/ SYSTEM_SPATIAL_CELL_SIZE
		)

		for offset_x in range(
			-cell_radius,
			cell_radius + 1
		):
			for offset_y in range(
				-cell_radius,
				cell_radius + 1
			):
				var cell_key: Vector2i = Vector2i(
					center_x + offset_x,
					center_y + offset_y
				)

				var systems_in_cell: Array = (
					_system_spatial_grid.get(
						cell_key,
						[]
					)
				)

				for system_value in systems_in_cell:
					var system_id: int = (
						int(system_value)
					)

					if explored_lookup.has(
						system_id
					):
						continue

					var target_position: Vector2 = (
						_system_positions.get(
							system_id,
							Vector2.INF
						)
					)

					if target_position == Vector2.INF:
						continue

					if origin_position.distance_squared_to(
						target_position
					) > interaction_range_squared:
						continue

					frontier[
						system_id
					] = true

	_civilization_exploration_frontiers[
		civilization_id
	] = frontier

	_civilization_exploration_ranges[
		civilization_id
	] = exploration_range
	
func _expand_exploration_frontier(
	civilization: CivilizationData,
	discovered_system_id: int,
	exploration_range: float
) -> void:
	if civilization == null:
		return

	if exploration_range <= 0.0:
		return

	var civilization_id: int = (
		civilization.global_id
	)

	if not _civilization_exploration_frontiers.has(
		civilization_id
	):
		_civilization_exploration_frontiers[
			civilization_id
		] = {}

	var frontier: Dictionary = (
		_civilization_exploration_frontiers[
			civilization_id
		]
	)

	var origin_position: Vector2 = (
		_system_positions.get(
			discovered_system_id,
			Vector2.INF
		)
	)

	if origin_position == Vector2.INF:
		return

	var exploration_range_squared: float = (
		exploration_range
		* exploration_range
	)

	var cell_radius: int = ceili(
		exploration_range
		/ SYSTEM_SPATIAL_CELL_SIZE
	)

	var explored_lookup: Dictionary = {}

	for system_id in civilization.explored_system_ids:
		explored_lookup[
			int(system_id)
		] = true

	var center_x: int = floori(
		origin_position.x
		/ SYSTEM_SPATIAL_CELL_SIZE
	)

	var center_y: int = floori(
		origin_position.y
		/ SYSTEM_SPATIAL_CELL_SIZE
	)

	for offset_x in range(
		-cell_radius,
		cell_radius + 1
	):
		for offset_y in range(
			-cell_radius,
			cell_radius + 1
		):
			var cell_key: Vector2i = Vector2i(
				center_x + offset_x,
				center_y + offset_y
			)

			var systems_in_cell: Array = (
				_system_spatial_grid.get(
					cell_key,
					[]
				)
			)

			for system_value in systems_in_cell:
				var system_id: int = (
					int(system_value)
				)

				if explored_lookup.has(
					system_id
				):
					continue

				var target_position: Vector2 = (
					_system_positions.get(
						system_id,
						Vector2.INF
					)
				)

				if target_position == Vector2.INF:
					continue

				if origin_position.distance_squared_to(
					target_position
				) > exploration_range_squared:
					continue

				frontier[
					system_id
				] = true

	_civilization_exploration_ranges[
		civilization_id
	] = exploration_range

func _register_independent_civilization(
	civilization: CivilizationData,
	planet: PlanetData
) -> void:
	var civilization_id: int = civilization.global_id

	_civilizations[civilization_id] = civilization

	# Système d'origine.
	var system_id: int = int(
		_planet_system_ids.get(
			planet.global_id,
			-1
		)
	)

	_civilization_system_ids[civilization_id] = system_id

	# Position de la civilisation.
	_civilization_positions[civilization_id] = (
		_system_positions.get(
			system_id,
			Vector2.ZERO
		)
	)

	# Structures diplomatiques.
	_civilization_allies[civilization_id] = []

	# Structures territoriales.
	_civilization_controlled_system_ids[
		civilization_id
	] = {}

	_civilization_territorial_claims[
		civilization_id
	] = {}

	# Exploration.
	_civilization_exploration_frontiers[
		civilization_id
	] = {}

	_civilization_exploration_ranges[
		civilization_id
	] = 0.0

	# Colonisation.
	_civilization_next_colonization_year[
		civilization_id
	] = (
		current_year
		+ COLONIZATION_COOLDOWN
	)

	# Distances et caches.
	_civilization_system_closest_distances[
		civilization_id
	] = {}

	_civilization_claim_distance_cache[
		civilization_id
	] = {}

	_civilization_interaction_ranges[
		civilization_id
	] = 0.0

	_civilization_system_influence[
		civilization_id
	] = {}

	# Les relations devront être recalculées.
	_civilization_allies_dirty = true


func save_to_dict() -> Dictionary:
	var systems_data: Array = []

	for system_key in _systems.keys():
		var system_id: int = int(system_key)

		if not _systems.has(system_id):
			continue

		var system: Dictionary = _systems[system_id]

		var planets_data: Array = []

		for planet in system.get("planets", []):
			if planet == null:
				continue

			planets_data.append(
				planet.to_dict()
			)

		var belts_data: Array = []

		for belt in system.get("asteroid_belts", []):
			if belt == null:
				continue

			belts_data.append(
				belt.to_dict()
			)

		var comets_data: Array = []

		for comet in system.get("comets", []):
			if comet == null:
				continue

			comets_data.append(
				comet.to_dict()
			)

		systems_data.append(
			{
				"id": system_id,
				"seed": system.get(
					"seed",
					0
				),
				"star_type": system.get(
					"star_type",
					""
				),
				"star_luminosity": system.get(
					"star_luminosity",
					0.0
				),
				"position": system.get(
					"position",
					Vector2.ZERO
				),
				"planets": planets_data,
				"asteroid_belts": belts_data,
				"comets": comets_data
			}
		)

	var civilizations_data := {}

	for civ_id in _civilizations.keys():
		civilizations_data[int(civ_id)] = (
			_civilizations[int(civ_id)].to_dict()
		)

	var relations_data := {}

	for key in _relations.keys():
		relations_data[str(key)] = (
			_relations[key].to_dict()
		)

	return {
		"version": 1,
		"current_year": current_year,
		"player_civilization_id": player_civilization_id,
		"next_civilization_id": _next_civilization_id,
		"next_civilization_global_id": _next_civilization_global_id,
		"relation_discovery_year": _relation_discovery_year,
		"systems": systems_data,
		"civilizations": civilizations_data,
		"relations": relations_data,
		"civilization_system_ids": _civilization_system_ids,
		"civilization_positions": _civilization_positions,
		"civilization_controlled_system_ids": _civilization_controlled_system_ids,
		"civilization_territorial_claims": _civilization_territorial_claims
	}


func load_from_dict(data: Dictionary) -> void:
	_clear_simulation_state()

	current_year = int(data["current_year"])
	player_civilization_id = int(data["player_civilization_id"])
	_next_civilization_id = int(data["next_civilization_id"])
	_next_civilization_global_id = int(data["next_civilization_global_id"])
	_relation_discovery_year = int(data["relation_discovery_year"])

	var civilizations_data: Dictionary = (
		data["civilizations"]
	)

	for civ_key in civilizations_data.keys():
		var civilian := CivilizationData.new()

		civilian.from_dict(
			civilizations_data[civ_key]
		)

		_civilizations[
			int(civ_key)
		] = civilian

	var colonies_by_planet := {}

	for civ in _civilizations.values():
		for colony in civ.colonies:
			colonies_by_planet[
				colony.planet_id
			] = colony

	var systems_data: Array = data["systems"]

	for system_data in systems_data:
		var system_id: int = int(
			system_data["id"]
		)

		var system := {
			"id": system_id,
			"seed": system_data["seed"],
			"star_type": system_data["star_type"],
			"star_luminosity": system_data["star_luminosity"],
			"position": system_data["position"]
		}

		_system_positions[
			system_id
		] = system["position"]

		var planets: Array[PlanetData] = []

		for planet_data in system_data["planets"]:
			var planet := PlanetData.new()

			planet.from_dict(planet_data)

			planets.append(planet)

			_planets[
				planet.global_id
			] = planet

			_planet_system_ids[
				planet.global_id
			] = system_id

			var home_civ_id: int = int(
				planet_data["civilization_id"]
			)

			if (
				home_civ_id >= 0
				and _civilizations.has(home_civ_id)
			):
				planet.civilization = (
					_civilizations[home_civ_id]
				)

			if colonies_by_planet.has(
				planet.global_id
			):
				planet.colony = (
					colonies_by_planet[
						planet.global_id
					]
				)

			if (
				planet.type != "gas_giant"
				and planet.civilization == null
				and planet.colony_owner_id == -1
				and planet.habitability >= 30.0
			):
				_colonizable_planets.append(
					planet
				)

				_colonizable_planet_system_ids[
					planet.global_id
				] = system_id

		system["planets"] = planets

		# Astéroïdes et comètes : restaurés depuis la sauvegarde,
		# ou régénérés pour les sauvegardes anciennes.
		var belts: Array[AsteroidBeltData] = []
		var comets: Array[CometData] = []

		if system_data.has("asteroid_belts"):
			for belt_data in system_data["asteroid_belts"]:
				var belt := AsteroidBeltData.new()
				belt.from_dict(belt_data)
				belts.append(belt)

			for comet_data in system_data["comets"]:
				var comet := CometData.new()
				comet.from_dict(comet_data)
				comets.append(comet)
		else:
			var regenerated: Dictionary = (
				_system_generator.generate_asteroids_and_comets(
					int(system_data["seed"]),
					planets,
					system_id
				)
			)

			belts = regenerated["asteroid_belts"]
			comets = regenerated["comets"]

		system["asteroid_belts"] = belts
		system["comets"] = comets

		_system_planets[system_id] = planets
		_systems[system_id] = system

	for key in data["relations"].keys():
		var relation := RelationData.new()

		relation.from_dict(
			data["relations"][key]
		)

		_relations[str(key)] = relation

	for civ_key in data["civilization_system_ids"].keys():
		_civilization_system_ids[int(civ_key)] = int(
			data["civilization_system_ids"][civ_key]
		)

	for civ_key in data["civilization_positions"].keys():
		_civilization_positions[int(civ_key)] = (
			data["civilization_positions"][civ_key]
		)

	for civ_key in data["civilization_controlled_system_ids"].keys():
		_civilization_controlled_system_ids[int(civ_key)] = (
			data["civilization_controlled_system_ids"][civ_key]
		)

	for civ_key in data["civilization_territorial_claims"].keys():
		_civilization_territorial_claims[int(civ_key)] = (
			data["civilization_territorial_claims"][civ_key]
		)

	_build_civilization_spatial_grid()
	_build_colonizable_planet_spatial_grid()
	_rebuild_system_spatial_grid()

	_civilization_allies_dirty = true
	_rebuild_civilization_allies()

	_reconcile_home_colonies()


func _reconcile_home_colonies() -> void:
	for planet in _planets.values():
		if planet == null:
			continue

		if planet.colony != null:
			continue

		if planet.population <= 0:
			continue

		var owner: CivilizationData = (
			planet.civilization
		)

		if (
			owner == null
			and planet.colony_owner_id >= 0
			and _civilizations.has(
				planet.colony_owner_id
			)
		):
			owner = _civilizations[
				planet.colony_owner_id
			]

		if owner == null:
			continue

		owner.attach_home_colony(
			planet
		)


func _clear_simulation_state() -> void:
	_systems.clear()
	_relations.clear()
	_civilizations.clear()
	_civilization_interaction_ranges.clear()
	_planets.clear()
	_planet_system_ids.clear()
	_system_positions.clear()
	_civilization_system_ids.clear()
	_system_planets.clear()
	_colonizable_planets.clear()
	_colonizable_planet_system_ids.clear()
	_civilization_positions.clear()
	_civilization_spatial_grid.clear()
	_colonizable_planet_spatial_grid.clear()
	_civilization_next_colonization_year.clear()
	_civilization_controlled_system_ids.clear()
	_civilization_territorial_claims.clear()
	_civilization_allies.clear()
	_system_spatial_grid.clear()
	_civilization_exploration_frontiers.clear()
	_civilization_exploration_ranges.clear()
	_civilization_system_closest_distances.clear()
	_civilization_claim_distance_cache.clear()
	_civilization_system_influence.clear()
	_contested_systems.clear()

	_year_accumulator = 0.0
