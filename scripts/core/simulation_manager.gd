class_name SimulationManager
extends Node


signal year_changed(year: int)


@export var years_per_second: float = 1.0
@export var simulation_running: bool = true
	
var current_year: int = 0
var _year_accumulator: float = 0.0
var _systems: Dictionary = {}
var _system_generator := SystemGenerator.new()
var _relations: Dictionary = {}

func initialize(stars: Array[Dictionary]) -> void:
	_systems.clear()
	_relations.clear()

	for star in stars:
		var star_id: int = star["id"]
		var system_seed: int = star["system_seed"]
		var star_type: String = star["type"]

		var system: Dictionary = _system_generator.generate(
			system_seed,
			star_type,
			star_id
		)

		system["star_id"] = star_id
		system["position"] = star["position"]

		_systems[star_id] = system

	_create_all_relations()

	print(
		"Simulation initialisée avec ",
		_systems.size(),
		" systèmes."
	)

func _process(delta: float) -> void:
	if not simulation_running:
		return

	_year_accumulator += delta * years_per_second

	while _year_accumulator >= 1.0:
		_year_accumulator -= 1.0
		_advance_year()


func _advance_year() -> void:
	current_year += 1

	_reset_trade_income()

	_simulate_all_systems()

	_update_dynamic_relations()

	_simulate_all_relations()

	year_changed.emit(current_year)


func _simulate_all_systems() -> void:
	for system in _systems.values():
		_simulate_system(system)


func _simulate_system(system: Dictionary) -> void:
	var planets: Array[PlanetData] = system["planets"]

	for planet in planets:
		if planet.civilization == null:
			continue

		planet.civilization.simulate_year(
			planet.habitability
		)

		planet.civilization.simulate_economy_and_technology(
			planet.habitability,
			planet.minerals,
			planet.energy,
			planet.biological_resources
		)

		for colony in planet.civilization.colonies:
			colony.simulate_year(
				planet.civilization.economy,
				planet.civilization.technology
			)

	_try_dynamic_colonization(
		planets
	)


func _try_dynamic_colonization(
	planets: Array[PlanetData]
) -> void:
	for source_planet in planets:
		var civilization: CivilizationData = (
			source_planet.civilization
		)

		if civilization == null:
			continue

		var space_stage: String = (
			civilization.get_space_stage()
		)

		if space_stage != "interplanetary" \
		and space_stage != "interstellar":
			continue

		var rng := RandomNumberGenerator.new()

		rng.seed = (
			civilization.seed
			+ current_year
			+ source_planet.id * 1000
		)

		var attempt_probability: float = 0.02

		if space_stage == "interstellar":
			attempt_probability = 0.05

		if rng.randf() > attempt_probability:
			continue

		for target_planet in planets:
			if target_planet.id == source_planet.id:
				continue

			if target_planet.civilization != null:
				continue

			if target_planet.colony_owner_id != -1:
				continue

			if target_planet.habitability < 20.0:
				continue

			var colonization_chance: float = (
				civilization.space_capability / 100.0
			)

			if rng.randf() > colonization_chance:
				continue

			target_planet.colony_owner_id = civilization.global_id

			var colony_seed: int = rng.randi()

			civilization.add_colony(
				colony_seed,
				target_planet
			)

			print(
				"Colonisation : ",
				civilization.name,
				" colonise la planète #",
				target_planet.id
			)

			break


func get_system(star_id: int) -> Dictionary:
	if not _systems.has(star_id):
		return {}

	return _systems[star_id]

func get_current_year() -> int:
	return current_year

func _create_all_relations() -> void:
	var civilizations: Array[Dictionary] = []

	for system in _systems.values():
		var planets: Array[PlanetData] = system["planets"]
		var position: Vector2 = system["position"]

		for planet in planets:
			if planet.civilization == null:
				continue

			civilizations.append({
				"civilization": planet.civilization,
				"position": position
			})

	for i in civilizations.size():
		var data_a: Dictionary = civilizations[i]

		var civilization_a: CivilizationData = (
			data_a["civilization"]
		)

		var position_a: Vector2 = (
			data_a["position"]
		)

		for j in range(i + 1, civilizations.size()):
			var data_b: Dictionary = civilizations[j]

			var civilization_b: CivilizationData = (
				data_b["civilization"]
			)

			var position_b: Vector2 = (
				data_b["position"]
			)

			var distance: float = (
				position_a.distance_to(position_b)
			)

			# Les civilisations trop éloignées
			# ne peuvent pas encore interagir.
			var range_a: float = (
				civilization_a.get_interaction_range()
			)

			var range_b: float = (
				civilization_b.get_interaction_range()
			)

			var interaction_range: float = min(
				range_a,
				range_b
			)

			if distance > interaction_range:
				continue

			var relation_seed: int = (
				civilization_a.seed
				+ civilization_b.seed
			)

			var relation := RelationData.new()

			relation.initialize(
				civilization_a.id,
				civilization_b.id,
				relation_seed,
				distance
			)

			var key := _get_relation_key(
				civilization_a.id,
				civilization_b.id
			)

			_relations[key] = relation

func _get_relation_key(
	civilization_a_id: int,
	civilization_b_id: int
) -> String:
	var first_id: int = min(
		civilization_a_id,
		civilization_b_id
	)

	var second_id: int = max(
		civilization_a_id,
		civilization_b_id
	)

	return str(first_id) + ":" + str(second_id)

func _simulate_all_relations() -> void:
	for relation in _relations.values():
		var civilization_a: CivilizationData = (
			_find_civilization(
				relation.civilization_a_id
			)
		)

		var civilization_b: CivilizationData = (
			_find_civilization(
				relation.civilization_b_id
			)
		)

		if civilization_a == null:
			continue

		if civilization_b == null:
			continue

		relation.simulate_year(
			civilization_a.economy,
			civilization_b.economy,
			civilization_a.technology,
			civilization_b.technology
		)

		if relation.at_war:
			civilization_a.apply_war_effect()
			civilization_b.apply_war_effect()

			var war_message: String = (
				relation.simulate_war_year(
					current_year,
					civilization_a.military_power,
					civilization_b.military_power
				)
			)

			if war_message != "":
				print(
					"[Guerre] ",
					war_message
				)

				if relation.last_war_winner == civilization_a.id:
					var conquest_message: String = (
						_try_conquer_colony(
							relation,
							civilization_a,
							civilization_b
						)
					)

					if conquest_message != "":
						print(
							"[Conquête] ",
							conquest_message
						)

				elif relation.last_war_winner == civilization_b.id:
					var conquest_message: String = (
						_try_conquer_colony(
							relation,
							civilization_b,
							civilization_a
						)
					)

					if conquest_message != "":
						print(
							"[Conquête] ",
							conquest_message
						)

			continue

		_try_start_war(
			relation,
			civilization_a,
			civilization_b
		)

		if relation.at_war:
			continue

		var event_message: String = (
			relation.simulate_event(
				current_year,
				civilization_a,
				civilization_b
			)
		)

		if event_message != "":
			print(
				"[Diplomatie] ",
				event_message
			)

		if relation.trade_value > 0.0:
			civilization_a.add_trade_income(
				relation.trade_value
			)

			civilization_b.add_trade_income(
				relation.trade_value
			)
func _find_civilization(
	civilization_id: int
) -> CivilizationData:
	for system in _systems.values():
		var planets: Array[PlanetData] = system["planets"]

		for planet in planets:
			if planet.civilization == null:
				continue

			if planet.civilization.id == civilization_id:
				return planet.civilization

	return null

func _reset_trade_income() -> void:
	for system in _systems.values():
		var planets: Array[PlanetData] = system["planets"]

		for planet in planets:
			if planet.civilization == null:
				continue

			planet.civilization.reset_trade_income()

func get_civilization_relations(
	civilization_id: int
) -> Array[RelationData]:
	var result: Array[RelationData] = []

	for relation in _relations.values():
		if relation.civilization_a_id == civilization_id \
		or relation.civilization_b_id == civilization_id:
			result.append(relation)

	return result

func get_other_civilization_id(
	relation: RelationData,
	civilization_id: int
) -> int:
	if relation.civilization_a_id == civilization_id:
		return relation.civilization_b_id

	return relation.civilization_a_id

func get_civilization(
	civilization_id: int
) -> CivilizationData:
	return _find_civilization(
		civilization_id
	)

func _update_dynamic_relations() -> void:
	var civilizations: Array[Dictionary] = []

	for system in _systems.values():
		var planets: Array[PlanetData] = system["planets"]
		var position: Vector2 = system["position"]

		for planet in planets:
			if planet.civilization == null:
				continue

			civilizations.append({
				"civilization": planet.civilization,
				"position": position
			})

	for i in civilizations.size():
		var data_a: Dictionary = civilizations[i]

		var civilization_a: CivilizationData = (
			data_a["civilization"]
		)

		var position_a: Vector2 = (
			data_a["position"]
		)

		for j in range(i + 1, civilizations.size()):
			var data_b: Dictionary = civilizations[j]

			var civilization_b: CivilizationData = (
				data_b["civilization"]
			)

			if civilization_a.id == civilization_b.id:
				continue

			var key := _get_relation_key(
				civilization_a.id,
				civilization_b.id
			)

			if _relations.has(key):
				continue

			var position_b: Vector2 = (
				data_b["position"]
			)

			var distance: float = (
				position_a.distance_to(position_b)
			)

			var range_a: float = (
				civilization_a.get_interaction_range()
			)

			var range_b: float = (
				civilization_b.get_interaction_range()
			)

			var interaction_range: float = min(
				range_a,
				range_b
			)

			if distance > interaction_range:
				continue

			var relation_seed: int = (
				civilization_a.seed
				+ civilization_b.seed
			)

			var relation := RelationData.new()

			relation.initialize(
				civilization_a.id,
				civilization_b.id,
				relation_seed,
				distance
			)

			_relations[key] = relation

			print(
				"[Diplomatie] Nouvelle relation : ",
				civilization_a.name,
				" ↔ ",
				civilization_b.name
			)

func _try_start_war(
	relation: RelationData,
	civilization_a: CivilizationData,
	civilization_b: CivilizationData
) -> void:
	if relation.at_war:
		return

	if relation.relation > -60.0:
		return

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		civilization_a.seed
		+ civilization_b.seed
		+ current_year
	)

	var war_probability: float = 0.02

	if relation.relation <= -80.0:
		war_probability = 0.05

	if rng.randf() > war_probability:
		return

	var message: String = relation.start_war(
		current_year
	)

	if message != "":
		print(
			"[Guerre] ",
			message
		)

func _try_conquer_colony(
	relation: RelationData,
	victorious_civilization: CivilizationData,
	defeated_civilization: CivilizationData
) -> String:
	if victorious_civilization == null:
		return ""

	if defeated_civilization == null:
		return ""

	if defeated_civilization.colonies.is_empty():
		return ""

	var rng := RandomNumberGenerator.new()

	rng.seed = (
		victorious_civilization.seed
		+ defeated_civilization.seed
		+ current_year
	)

	var conquest_chance: float = 0.5

	if rng.randf() > conquest_chance:
		return ""

	var colony_index: int = rng.randi_range(
		0,
		defeated_civilization.colonies.size() - 1
	)

	var colony: ColonyData = (
		defeated_civilization.colonies[colony_index]
	)

	var planet_id: int = colony.planet_id

	var removed_colony: ColonyData = (
		defeated_civilization.remove_colony(
			planet_id
		)
	)

	if removed_colony == null:
		return ""

	victorious_civilization.take_over_colony(
		removed_colony
	)

	var system: Dictionary = (
		_find_system_containing_planet(
			planet_id
		)
	)

	if not system.is_empty():
		var planets: Array[PlanetData] = (
			system["planets"]
		)

		for planet in planets:
			if planet.global_id != planet_id:
				continue

			planet.colony_owner_id = (
				victorious_civilization.global_id
			)

			break

	var message := (
		victorious_civilization.name
		+ " prend le contrôle de la colonie de "
		+ defeated_civilization.name
		+ " sur la planète #"
		+ str(planet_id)
		+ "."
	)

	return message
	
func _find_system_containing_planet(
	planet_global_id: int
) -> Dictionary:
	for system in _systems.values():
		var planets: Array[PlanetData] = (
			system["planets"]
		)

		for planet in planets:
			if planet.global_id != planet_global_id:
				continue

			return system

	return {}
