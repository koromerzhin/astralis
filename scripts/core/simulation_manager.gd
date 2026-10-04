class_name SimulationManager
extends Node


signal year_changed(year: int)

const CIVILIZATION_SPATIAL_CELL_SIZE := 400.0
const RELATION_DISCOVERY_INTERVAL := 10
const PLANET_SPATIAL_CELL_SIZE := 400.0
const COLONIZATION_COOLDOWN := 5

@export var years_per_second: float = 1.0
@export var simulation_running: bool = true


var current_year: int = 0
var _year_accumulator: float = 0.0
var _next_civilization_id: int = 0
var _next_civilization_global_id: int = 0
var _relation_discovery_year: int = -1

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

	if (
		_relation_discovery_year < 0
		or current_year >= _relation_discovery_year
	):
		_update_dynamic_relations()

		_relation_discovery_year = (
			current_year
			+ RELATION_DISCOVERY_INTERVAL
		)

	var end_dynamic_relations := Time.get_ticks_usec()

	_evaluate_territorial_tensions()
	var start_relations := Time.get_ticks_usec()
	_simulate_all_relations()
	_update_controlled_territories()
	_update_territorial_claims()
	_evaluate_territorial_claim_conflicts()
	_evaluate_territorial_demands()
	_process_territorial_demands()
	var end_relations := Time.get_ticks_usec()

	var start_trade := Time.get_ticks_usec()
	_evaluate_trade_decisions()
	var end_trade := Time.get_ticks_usec()

	var start_war_decisions := Time.get_ticks_usec()
	_evaluate_war_decisions()
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
		" | Relations: ",
		(end_relations - start_relations) / 1000.0,
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
			planet.population_capacity,
			planet.habitability
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

			colony_planet.population_capacity = (
				colony.population_capacity
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
			_apply_war_damage(
				civilization_a,
				civilization_b,
				relation
			)

			var war_result: String = (
				relation.simulate_war_year(
					current_year,
					civilization_a.military_power,
					civilization_b.military_power
				)
			)

			if not war_result.is_empty():
				print(
					"[Guerre] ",
					war_result
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
		print(
			"[Guerre] ",
			civilization_a.name,
			" déclare la guerre à ",
			civilization_b.name
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
		print(
			"[Revanche] ",
			civilization_a.name,
			" déclenche une guerre de revanche contre ",
			civilization_b.name
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

			print(
				"[Alliance] ",
				civilization_a.name,
				" et ",
				civilization_b.name,
				" deviennent alliés."
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

				print(
					"[Alliance] ",
					civilization_a.name,
					" et ",
					civilization_b.name,
					" rompent leur alliance."
				)

				continue

			if relation.can_break_alliance():
				relation.alliance = false
				_civilization_allies_dirty = true

				print(
					"[Alliance] ",
					civilization_a.name,
					" et ",
					civilization_b.name,
					" rompent leur alliance."
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

func _try_dynamic_colonization() -> void:
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.is_empty():
		return

	var available_planets: Array[PlanetData] = []

	for planet in _colonizable_planets:
		if planet == null:
			continue

		if planet.civilization != null:
			continue

		if planet.colony_owner_id != -1:
			continue

		if planet.habitability < 30.0:
			continue

		available_planets.append(
			planet
		)

	if available_planets.is_empty():
		return

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

		var candidates: Array[PlanetData] = []

		for planet in available_planets:
			if planet == null:
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

			var reachable: bool = false

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

				if distance <= interaction_range:
					reachable = true
					break

			if not reachable:
				continue

			# Une civilisation ne colonise pas son propre système.
			var system_owner: CivilizationData = (
				_find_civilization_in_system(
					target_system_id
				)
			)

			if system_owner == civilization:
				continue

			candidates.append(
				planet
			)

		if candidates.is_empty():
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = (
			civilization.seed
			+ current_year * 31337
			+ civilization.colony_planet_ids.size() * 7919
		)

		var best_score: float = -INF
		var best_planet: PlanetData = null

		for candidate in candidates:
			if candidate == null:
				continue

			var candidate_system_value = (
				_colonizable_planet_system_ids.get(
					candidate.global_id,
					null
				)
			)

			if candidate_system_value == null:
				continue

			var candidate_system_id: int = (
				int(candidate_system_value)
			)

			var territorial_pressure: float = (
				_calculate_territorial_pressure(
					civilization,
					candidate_system_id
				)
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

		print(
			"[Colonisation] ",
			civilization.name,
			" colonise la planète #",
			planet.global_id,
			" dans le système #",
			target_system_id
		)

		available_planets.erase(
			planet
		)

		_colonizable_planets.erase(
			planet
		)

		_colonizable_planet_system_ids.erase(
			planet.global_id
		)

		# Une seule colonisation par civilisation et par année.
		break

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

			if colony.stability < 20.0:
				rebellion_chance = 1.0
			else:
				rebellion_chance *= 0.002

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

			civilization.remove_colony(
				colony.planet_id
			)

			target_planet.civilization = (
				new_civilization
			)

			target_planet.colony_owner_id = -1

			target_planet.population = (
				new_civilization.population
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

	target_planet.population = (
		rebel_civilization.population
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

	print(
		"[Rébellion] ",
		rebel_civilization.name,
		" devient indépendante sur la planète #",
		target_planet.global_id
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

		var stability_score: float = (
			100.0
			- colony.stability
		)

		var strategic_score: float = (
			proximity_score
			+ stability_score * 2.0
		)

		if strategic_score <= best_score:
			continue

		best_score = strategic_score
		target_colony = colony

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

	print(
		"[Conquête] ",
		winner.name,
		" capture la colonie #",
		planet_id,
		" dans le système #",
		target_system_id,
		" de ",
		loser.name
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

		print(
			"[Guerre] ",
			civilization_a.name,
			" déclare la guerre à ",
			civilization_b.name
		)

func _evaluate_trade_decisions() -> void:
	for relation in _relations.values():
		if relation == null:
			continue

		if relation.at_war:
			relation.trade = 0.0
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

		var wants_a: bool = (
			civilization_a.wants_to_trade(
				civilization_b
			)
		)

		var wants_b: bool = (
			civilization_b.wants_to_trade(
				civilization_a
			)
		)

		if wants_a and wants_b:
			relation.trade = min(
				relation.trade + 5.0,
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
				relation.trade_value * 0.01
			)

			civilization_a.add_trade_income(
				trade_income
			)

			civilization_b.add_trade_income(
				trade_income
			)

			# Le commerce permet également de partager
			# progressivement des informations territoriales.
			_share_territories_between_civilizations(
				civilization_a,
				civilization_b,
				relation
			)

		else:
			relation.trade = max(
				relation.trade - 2.0,
				0.0
			)

			if relation.trade <= 0.0:
				relation.trade_value = 0.0

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

		# Une civilisation peut désormais explorer à partir
		# de n'importe quel système qu'elle connaît déjà.
		var known_systems: Array[int] = (
			civilization.explored_system_ids
		)

		if known_systems.is_empty():
			continue

		var possible_systems: Array[int] = []

		for known_system_id in known_systems:
			var origin_position: Vector2 = (
				_system_positions.get(
					known_system_id,
					Vector2.INF
				)
			)

			if origin_position == Vector2.INF:
				continue

			for other_system_id in _systems.keys():
				var other_id: int = (
					int(other_system_id)
				)

				if civilization.has_explored_system(
					other_id
				):
					continue

				var other_position: Vector2 = (
					_system_positions.get(
						other_id,
						Vector2.INF
					)
				)

				if other_position == Vector2.INF:
					continue

				var distance: float = (
					origin_position.distance_to(
						other_position
					)
				)

				if distance > exploration_range:
					continue

				possible_systems.append(
					other_id
				)

		if possible_systems.is_empty():
			continue

		# Évite qu'un même système apparaisse plusieurs fois
		# lorsque plusieurs systèmes connus permettent de l'atteindre.
		possible_systems = (
			possible_systems.duplicate()
		)

		var unique_systems: Array[int] = []

		for possible_system_id in possible_systems:
			if unique_systems.has(
				possible_system_id
			):
				continue

			unique_systems.append(
				possible_system_id
			)

		if unique_systems.is_empty():
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = (
			civilization.seed
			+ current_year * 1543
			+ civilization.explored_system_ids.size() * 7919
		)

		var discovered_system_id: int = (
			unique_systems[
				rng.randi_range(
					0,
					unique_systems.size() - 1
				)
			]
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

		# La civilisation exploratrice découvre le système
		# où se trouve la civilisation rencontrée.
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

		# La civilisation rencontrée apprend où se trouve
		# la civilisation exploratrice.
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

		# Si le système découvert contient une colonie,
		# son propriétaire est également identifié.
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

		print(
			"[Premier contact] ",
			civilization.name,
			" rencontre ",
			discovered_civilization.name
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

	for i in civilizations.size():
		var civilization_a: CivilizationData = (
			civilizations[i]
		)

		if civilization_a == null:
			continue

		var controlled_a: Array = (
			_civilization_controlled_system_ids.get(
				civilization_a.global_id,
				[]
			)
		)

		if controlled_a.is_empty():
			continue

		for j in range(i + 1, civilizations.size()):
			var civilization_b: CivilizationData = (
				civilizations[j]
			)

			if civilization_b == null:
				continue

			var controlled_b: Array = (
				_civilization_controlled_system_ids.get(
					civilization_b.global_id,
					[]
				)
			)

			if controlled_b.is_empty():
				continue

			var closest_distance: float = INF

			for system_a_value in controlled_a:
				var system_a_id: int = (
					int(system_a_value)
				)

				var position_a: Vector2 = (
					_system_positions.get(
						system_a_id,
						Vector2.INF
					)
				)

				if position_a == Vector2.INF:
					continue

				for system_b_value in controlled_b:
					var system_b_id: int = (
						int(system_b_value)
					)

					var position_b: Vector2 = (
						_system_positions.get(
							system_b_id,
							Vector2.INF
						)
					)

					if position_b == Vector2.INF:
						continue

					var distance: float = (
						position_a.distance_to(
							position_b
						)
					)

					if distance < closest_distance:
						closest_distance = distance

			if closest_distance == INF:
				continue

			var range_a: float = (
				civilization_a.get_interaction_range()
			)

			var range_b: float = (
				civilization_b.get_interaction_range()
			)

			var combined_range: float = (
				range_a + range_b
			)

			if combined_range <= 0.0:
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
	# Nettoyage des territoires contrôlés.
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

			var valid: bool = false

			for planet in _system_planets.get(
				system_id,
				[]
			):
				if planet == null:
					continue

				if planet.civilization != null:
					if (
						planet.civilization.global_id
						== int(civilization_id)
					):
						valid = true
						break

				if (
					planet.colony_owner_id
					== int(civilization_id)
				):
					valid = true
					break

			if valid and not valid_systems.has(system_id):
				valid_systems.append(system_id)

		_civilization_controlled_system_ids[
			civilization_id
		] = valid_systems
		
func _update_territorial_claims() -> void:
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
			continue

		var interaction_range: float = (
			civilization.get_interaction_range()
		)

		if interaction_range <= 0.0:
			continue

		for system_id_value in _systems.keys():
			var system_id: int = (
				int(system_id_value)
			)

			if controlled_systems.has(system_id):
				claims.erase(system_id)
				continue

			var target_position: Vector2 = (
				_system_positions.get(
					system_id,
					Vector2.INF
				)
			)

			if target_position == Vector2.INF:
				continue

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
				continue

			if closest_distance > interaction_range:
				claims.erase(system_id)
				continue

			var proximity: float = (
				1.0
				- closest_distance / interaction_range
			)

			proximity = clamp(
				proximity,
				0.0,
				1.0
			)

			var claim_strength: float = (
				proximity * 60.0
			)

			claim_strength += (
				civilization.expansionism
				* 0.40
			)

			claim_strength += (
				civilization.militarism
				* 0.10
			)

			claim_strength = clamp(
				claim_strength,
				0.0,
				100.0
			)

			claims[system_id] = claim_strength

		# On supprime les revendications devenues trop faibles.
		var systems_to_remove: Array[int] = []

		for claimed_system_value in claims.keys():
			var claimed_system_id: int = (
				int(claimed_system_value)
			)

			var claim_value: float = (
				float(
					claims[
						claimed_system_value
					]
				)
			)

			if claim_value < 10.0:
				systems_to_remove.append(
					claimed_system_id
				)

		for claimed_system_id in systems_to_remove:
			claims.erase(
				claimed_system_id
			)
			
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

	print(
		"[Territoire] ",
		winner.name,
		" prend le contrôle du système #",
		system_id,
		" à ",
		loser.name
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
