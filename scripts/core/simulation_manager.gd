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
	_civilization_positions.clear()
	_civilization_spatial_grid.clear()
	_system_planets.clear()
	_colonizable_planets.clear()
	_colonizable_planet_system_ids.clear()
	_colonizable_planet_spatial_grid.clear()
	_civilization_next_colonization_year.clear()
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
			
			_civilization_positions[
				civilization.global_id
			] = position

	_build_civilization_spatial_grid()
	_build_colonizable_planet_spatial_grid()
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

	var start_relations := Time.get_ticks_usec()
	_simulate_all_relations()
	var end_relations := Time.get_ticks_usec()

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
		" | Révoltes: ",
		(end_rebellions - start_rebellions) / 1000.0,
		" ms",
		" | Relations dynamiques: ",
		(end_dynamic_relations - start_dynamic_relations) / 1000.0,
		" ms",
		" | Relations: ",
		(end_relations - start_relations) / 1000.0,
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
	_relations.clear()

	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.size() < 2:
		return

	# -------------------------------------------------
	# CACHE DES POSITIONS ET PORTÉES
	# -------------------------------------------------

	var positions: Dictionary = {}
	var interaction_ranges: Dictionary = {}

	for civilization in civilizations:
		if civilization == null:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		var system_id = (
			_civilization_system_ids.get(
				civilization_id,
				null
			)
		)

		if system_id == null:
			continue

		if not _system_positions.has(system_id):
			continue

		positions[civilization_id] = (
			_system_positions[system_id]
		)

		interaction_ranges[civilization_id] = (
			civilization.get_interaction_range()
		)

	# -------------------------------------------------
	# CRÉATION DES RELATIONS
	# -------------------------------------------------

	for i in civilizations.size():
		var civilization_a: CivilizationData = (
			civilizations[i]
		)

		if civilization_a == null:
			continue

		var civilization_a_id: int = (
			civilization_a.global_id
		)

		if not positions.has(civilization_a_id):
			continue

		var position_a: Vector2 = (
			positions[civilization_a_id]
		)

		var range_a: float = (
			interaction_ranges.get(
				civilization_a_id,
				0.0
			)
		)

		for j in range(i + 1, civilizations.size()):
			var civilization_b: CivilizationData = (
				civilizations[j]
			)

			if civilization_b == null:
				continue

			var civilization_b_id: int = (
				civilization_b.global_id
			)

			if not positions.has(civilization_b_id):
				continue

			var position_b: Vector2 = (
				positions[civilization_b_id]
			)

			var distance: float = (
				position_a.distance_to(
					position_b
				)
			)

			var range_b: float = (
				interaction_ranges.get(
					civilization_b_id,
					0.0
				)
			)

			var interaction_range: float = min(
				range_a,
				range_b
			)

			if distance > interaction_range:
				continue

			var key: String = (
				_get_relation_key(
					civilization_a_id,
					civilization_b_id
				)
			)

			if key.is_empty():
				continue

			if _relations.has(key):
				continue

			var relation := RelationData.new()

			var relation_seed: int = (
				civilization_a.seed
				+ civilization_b.seed * 31
			)

			relation.initialize(
				civilization_a_id,
				civilization_b_id,
				relation_seed,
				distance
			)

			_relations[key] = relation

func _update_dynamic_relations() -> void:
	var created_relations: int = 0
	var civilizations: Array[CivilizationData] = (
		_get_all_civilizations()
	)

	if civilizations.size() < 2:
		return

	for civilization in civilizations:
		if civilization == null:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		if not _civilization_positions.has(
			civilization_id
		):
			continue

		var position_a: Vector2 = (
			_civilization_positions[
				civilization_id
			]
		)

		var range_a: float = (
			civilization.get_interaction_range()
		)

		var cell: Vector2i = (
			_get_civilization_grid_cell(
				position_a
			)
		)

		# Nombre de cellules à parcourir autour
		# de la cellule de la civilisation.
		var cell_radius: int = (
			ceili(
				range_a
				/ CIVILIZATION_SPATIAL_CELL_SIZE
			)
		)

		for offset_x in range(
			-cell_radius,
			cell_radius + 1
		):
			for offset_y in range(
				-cell_radius,
				cell_radius + 1
			):
				var neighbor_cell := Vector2i(
					cell.x + offset_x,
					cell.y + offset_y
				)

				if not _civilization_spatial_grid.has(
					neighbor_cell
				):
					continue

				var neighbor_ids: Array = (
					_civilization_spatial_grid[
						neighbor_cell
					]
				)

				for civilization_b_id in neighbor_ids:
					var other_id: int = (
						civilization_b_id
					)

					if other_id <= civilization_id:
						continue

					var civilization_b: CivilizationData = (
						_civilizations.get(
							other_id,
							null
						)
					)

					if civilization_b == null:
						continue

					if not _civilization_positions.has(
						other_id
					):
						continue

					var range_b: float = (
						civilization_b.get_interaction_range()
					)

					var interaction_range: float = min(
						range_a,
						range_b
					)

					var position_b: Vector2 = (
						_civilization_positions[
							other_id
						]
					)

					var delta_x: float = (
						position_a.x
						- position_b.x
					)

					if abs(delta_x) > interaction_range:
						continue

					var delta_y: float = (
						position_a.y
						- position_b.y
					)

					if abs(delta_y) > interaction_range:
						continue

					var distance_squared: float = (
						delta_x * delta_x
						+ delta_y * delta_y
					)

					if distance_squared > (
						interaction_range
						* interaction_range
					):
						continue

					var key: String = (
						_get_relation_key(
							civilization_id,
							other_id
						)
					)

					if key.is_empty():
						continue

					if _relations.has(key):
						continue

					var relation := RelationData.new()

					var relation_seed: int = (
						civilization.seed
						+ civilization_b.seed * 31
						+ current_year * 997
					)

					relation.initialize(
						civilization_id,
						other_id,
						relation_seed,
						sqrt(distance_squared)
					)

					_relations[key] = relation
					created_relations += 1

					print(
						"[Diplomatie] Nouvelle relation entre ",
						civilization.name,
						" et ",
						civilization_b.name
					)
	
	if current_year == 18:
		print(
			"DIAGNOSTIC RELATIONS : ",
			civilizations.size(),
			" civilisations / ",
			_relations.size(),
			" relations"
		)
	if current_year <= 20:
		print(
			"RELATIONS CRÉÉES ANNÉE ",
			current_year,
			" : ",
			created_relations,
			" | TOTAL : ",
			_relations.size()
		)

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

		if relation.at_war:
			if relation.alliance:
				relation.alliance = false
				_civilization_allies_dirty = true
			continue

		if not relation.alliance:
			if relation.can_form_alliance():
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

	if _colonizable_planets.is_empty():
		return

	for civilization in civilizations:
		if civilization == null:
			continue

		var civilization_id: int = (
			civilization.global_id
		)

		var next_year: int = (
			_civilization_next_colonization_year.get(
				civilization_id,
				0
			)
		)

		if current_year < next_year:
			continue

		var stage: String = (
			civilization.get_space_stage()
		)

		if stage != "interplanetary" \
		and stage != "interstellar":
			continue

		var home_planet_id: int = (
			civilization.home_planet_id
		)

		var home_system_id = (
			_planet_system_ids.get(
				home_planet_id,
				null
			)
		)

		if home_system_id == null:
			continue

		var home_position: Vector2 = (
			_system_positions.get(
				home_system_id,
				Vector2.INF
			)
		)

		if home_position == Vector2.INF:
			continue

		var interaction_range: float = (
			civilization.get_interaction_range()
		)

		var range_squared: float = (
			interaction_range
			* interaction_range
		)

		var rng := RandomNumberGenerator.new()

		rng.seed = (
			civilization.seed
			+ current_year * 997
		)

		var colonization_probability: float = 0.01

		if stage == "interstellar":
			colonization_probability = 0.03

		if civilization.space_capability >= 80.0:
			colonization_probability += 0.02

		# Même lorsqu'une civilisation est éligible,
		# elle ne colonise pas nécessairement.
		if rng.randf() > colonization_probability:
			_civilization_next_colonization_year[
				civilization_id
			] = (
				current_year
				+ COLONIZATION_COOLDOWN
			)

			continue

		var possible_targets: Array[PlanetData] = []

		if stage == "interplanetary":
			var system_planets: Array[PlanetData] = (
				_system_planets.get(
					home_system_id,
					[]
				)
			)

			for target_planet in system_planets:
				if target_planet == null:
					continue

				if target_planet.global_id == home_planet_id:
					continue

				if target_planet.type == "gas_giant":
					continue

				if target_planet.civilization != null:
					continue

				if target_planet.colony_owner_id != -1:
					continue

				if target_planet.habitability < 30.0:
					continue

				possible_targets.append(
					target_planet
				)

		else:
			var home_cell: Vector2i = (
				_get_civilization_grid_cell(
					home_position
				)
			)

			var cell_radius: int = (
				ceili(
					interaction_range
					/ PLANET_SPATIAL_CELL_SIZE
				)
			)

			for offset_x in range(
				-cell_radius,
				cell_radius + 1
			):
				for offset_y in range(
					-cell_radius,
					cell_radius + 1
				):
					var cell := Vector2i(
						home_cell.x + offset_x,
						home_cell.y + offset_y
					)

					if not _colonizable_planet_spatial_grid.has(
						cell
					):
						continue

					var planet_ids: Array = (
						_colonizable_planet_spatial_grid[
							cell
						]
					)

					for planet_id in planet_ids:
						var target_planet: PlanetData = (
							_planets.get(
								planet_id,
								null
							)
						)

						if target_planet == null:
							continue

						if target_planet.global_id == home_planet_id:
							continue

						if target_planet.type == "gas_giant":
							continue

						if target_planet.civilization != null:
							continue

						if target_planet.colony_owner_id != -1:
							continue

						var target_system_id = (
							_colonizable_planet_system_ids.get(
								planet_id,
								null
							)
						)

						if target_system_id == null:
							continue

						if target_system_id == home_system_id:
							continue

						var target_position: Vector2 = (
							_system_positions.get(
								target_system_id,
								Vector2.INF
							)
						)

						if target_position == Vector2.INF:
							continue

						var delta_x: float = (
							home_position.x
							- target_position.x
						)

						if abs(delta_x) > interaction_range:
							continue

						var delta_y: float = (
							home_position.y
							- target_position.y
						)

						if abs(delta_y) > interaction_range:
							continue

						var distance_squared: float = (
							delta_x * delta_x
							+ delta_y * delta_y
						)

						if distance_squared > range_squared:
							continue

						possible_targets.append(
							target_planet
						)

		if possible_targets.is_empty():
			_civilization_next_colonization_year[
				civilization_id
			] = (
				current_year
				+ COLONIZATION_COOLDOWN
			)

			continue

		var target_planet: PlanetData = (
			possible_targets[
				rng.randi_range(
					0,
					possible_targets.size() - 1
				)
			]
		)

		var colony_seed: int = rng.randi()

		civilization.add_colony(
			colony_seed,
			target_planet
		)

		target_planet.colony_owner_id = (
			civilization.global_id
		)

		_colonizable_planet_system_ids.erase(
			target_planet.global_id
		)

		_colonizable_planets.erase(
			target_planet
		)

		var target_system_id = (
			_planet_system_ids.get(
				target_planet.global_id,
				null
			)
		)

		if target_system_id != null:
			var target_position: Vector2 = (
				_system_positions.get(
					target_system_id,
					Vector2.INF
				)
			)

			if target_position != Vector2.INF:
				var target_cell: Vector2i = (
					_get_civilization_grid_cell(
						target_position
					)
				)

				if _colonizable_planet_spatial_grid.has(
					target_cell
				):
					var planet_ids: Array = (
						_colonizable_planet_spatial_grid[
							target_cell
						]
					)

					planet_ids.erase(
						target_planet.global_id
					)

					if planet_ids.is_empty():
						_colonizable_planet_spatial_grid.erase(
							target_cell
						)

		_civilization_next_colonization_year[
			civilization_id
		] = (
			current_year
			+ COLONIZATION_COOLDOWN
		)

		print(
			"[Colonisation] ",
			civilization.name,
			" colonise la planète #",
			target_planet.global_id
		)

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

	# -------------------------------------------------
	# RECHERCHE DE LA COLONIE LA PLUS FRAGILE
	# -------------------------------------------------

	var target_colony: ColonyData = null
	var lowest_stability: float = INF

	for colony in loser.colonies:
		if colony == null:
			continue

		if colony.stability < lowest_stability:
			lowest_stability = colony.stability
			target_colony = colony

	if target_colony == null:
		return

	# -------------------------------------------------
	# TRANSFERT
	# -------------------------------------------------

	loser.remove_colony(
		target_colony.planet_id
	)

	winner.take_over_colony(
		target_colony
	)

	target_colony.set_occupied()

	# -------------------------------------------------
	# PLANÈTE
	# -------------------------------------------------

	var target_planet: PlanetData = (
		_planets.get(
			target_colony.planet_id,
			null
		)
	)

	if target_planet != null:
		target_planet.colony_owner_id = (
			winner.global_id
		)

	# -------------------------------------------------
	# JOURNAL
	# -------------------------------------------------

	print(
		"[Conquête] ",
		winner.name,
		" capture la colonie #",
		target_colony.planet_id,
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

		if not civilization_a.wants_to_declare_war(
			civilization_b
		):
			continue

		# Une civilisation ne déclare pas une guerre
		# contre une civilisation avec laquelle elle
		# entretient de bonnes relations.
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
