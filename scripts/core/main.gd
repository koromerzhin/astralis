extends Control


const GALAXY_SEED := 827391


var galaxy_generator := GalaxyGenerator.new()

var stars: Array[Dictionary] = []

var galaxy_camera_position := Vector2.ZERO
var galaxy_camera_zoom := Vector2.ONE

var current_star_id: int = -1
var current_system: Dictionary = {}
var current_planet: PlanetData
var simulation_year: int = 0

@onready var simulation_manager: SimulationManager = $SimulationManager

func _ready() -> void:
	stars = galaxy_generator.generate(GALAXY_SEED)
	$SimulationManager.initialize(stars)

	print("Galaxy generated with seed: ", GALAXY_SEED)
	print("Stars generated: ", stars.size())

	# Vue galaxie
	$Galaxy.set_stars(stars)
	$Galaxy.star_selected.connect(_on_star_selected)

	# Vue système
	$System.planet_selected.connect(_on_planet_selected)
	$SimulationManager.year_changed.connect(
		_on_year_changed
	)

	# État initial
	$StarInfo.visible = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$Galaxy.visible = true
	$Galaxy/Camera2D.enabled = true
	
	simulation_manager.year_changed.connect(
		_on_year_changed
	)


func _on_star_selected(star: Dictionary) -> void:
	var star_id: int = star["id"]
	var star_type: String = star["type"]
	var star_position: Vector2 = star["position"]
	var system_seed: int = star["system_seed"]

	# Sauvegarder l'état de la galaxie
	galaxy_camera_position = $Galaxy/Camera2D.position
	galaxy_camera_zoom = $Galaxy/Camera2D.zoom

	current_star_id = star_id

	# Générer le système à partir de son seed
	current_system = $SimulationManager.get_system(
		star_id
	)

	var info := "Système #" + str(star_id) + "\n\n"
	info += "Type : " + star_type + "\n"
	info += "Luminosité : "
	info += str(current_system["star_luminosity"])
	info += "\n"
	info += "Position : "
	info += str(round(star_position.x))
	info += ", "
	info += str(round(star_position.y))
	info += "\n"
	info += "Seed : " + str(system_seed) + "\n"
	info += "Planètes : "
	info += str(current_system["planets"].size())

	$StarInfo/InfoLabel.text = info

	_show_system()


func _on_planet_selected(planet: PlanetData) -> void:
	current_planet = planet

	var civilization_text := "Aucune civilisation"

	if planet.civilization != null:
		var civilization: CivilizationData = planet.civilization

		var space_stage: String = (
			civilization.get_space_stage()
		)

		var total_population: int = (
			civilization.get_total_population()
		)

		var total_production: float = (
			civilization.get_total_production()
		)

		var trade_income: float = (
			civilization.trade_income
		)

		var relations_text := ""

		var relations: Array[RelationData] = (
			$SimulationManager.get_civilization_relations(
				civilization.id
			)
		)

		for relation in relations:
			var other_id: int = (
				$SimulationManager.get_other_civilization_id(
					relation,
					civilization.id
				)
			)

			var other_civilization: CivilizationData = (
				$SimulationManager.get_civilization(
					other_id
				)
			)

			if other_civilization == null:
				continue

			relations_text += (
				"\n"
				+ other_civilization.name
				+ " : "
				+ relation.get_relation_status()
				+ " ("
				+ str(snapped(relation.relation, 0.1))
				+ ")"
				+ " | Commerce : "
				+ relation.get_trade_status()
				+ " ("
				+ str(snapped(relation.trade_value, 0.1))
				+ ")"
				+ " | Distance : "
				+ str(snapped(relation.distance, 1.0))
			)

			if relation.event_history.size() > 0:
				relations_text += "\nÉvénements récents :"

				for event in relation.event_history:
					relations_text += (
						"\n  • "
						+ event
					)

		civilization_text = (
			"Civilisation : "
			+ civilization.name
			+ "\n"
			+ "Population planète : "
			+ str(civilization.population)
			+ "\n"
			+ "Population totale : "
			+ str(total_population)
			+ "\n"
			+ "Colonies : "
			+ str(civilization.colony_planet_ids.size())
			+ "\n"
			+ "Production colonies : "
			+ str(snapped(total_production, 0.1))
			+ "\n"
			+ "Revenus commerciaux : "
			+ str(snapped(trade_income, 0.1))
			+ "\n"
			+ "Économie : "
			+ str(snapped(civilization.economy, 0.1))
			+ "\n"
			+ "Technologie : "
			+ str(snapped(civilization.technology, 0.1))
			+ "\n"
			+ "Capacité spatiale : "
			+ str(snapped(civilization.space_capability, 0.1))
			+ "\n"
			+ "Stade spatial : "
			+ space_stage
			+ "\n\nRelations :"
			+ relations_text
		)

	$StarInfo/InfoLabel.text = (
		"Planète #"
		+ str(planet.id)
		+ "\n"
		+ "Type : "
		+ planet.type
		+ "\n"
		+ "Taille : "
		+ str(snapped(planet.size, 0.1))
		+ "\n"
		+ "Habitabilité : "
		+ str(snapped(planet.habitability, 0.1))
		+ "\n"
		+ "Vie : "
		+ planet.life_stage
		+ "\n\n"
		+ civilization_text
	)

	$StarInfo.show()

func _show_system() -> void:
	$Galaxy.visible = false
	$Galaxy/Camera2D.enabled = false

	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$System.visible = true
	$System/Camera2D.enabled = true

	$StarInfo.visible = true

	$System.set_system(current_system)


func _show_galaxy() -> void:
	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Galaxy.visible = true
	$Galaxy/Camera2D.enabled = true

	# Restaurer la position et le zoom de la caméra
	$Galaxy/Camera2D.position = galaxy_camera_position
	$Galaxy/Camera2D.zoom = galaxy_camera_zoom

	$StarInfo.visible = false

	$Galaxy.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			$SimulationManager.simulation_running = (
				not $SimulationManager.simulation_running
			)

		elif event.pressed and event.keycode == KEY_ESCAPE:
			if $Planet.visible:
				_show_system()

			elif $System.visible:
				_show_galaxy()

func _on_year_changed(year: int) -> void:
	simulation_year = year

	print(
		"Année simulée : ",
		simulation_year
	)

	if $Planet.visible and current_planet != null:
		_on_planet_selected(current_planet)


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

		# Une civilisation ne tente pas nécessairement
		# une colonisation chaque année.
		var rng := RandomNumberGenerator.new()
		rng.seed = (
			civilization.seed
			+ simulation_year
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

			target_planet.colony_owner_id = civilization.id

			civilization.colony_planet_ids.append(
				target_planet.id
			)

			print(
				"Colonisation : ",
				civilization.name,
				" colonise la planète #",
				target_planet.id
			)

			break
