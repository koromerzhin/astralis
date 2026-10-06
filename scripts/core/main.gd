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
var player := PlayerData.new()
var selected_star: Dictionary = {}
var travel_button: Button
var interaction_button: Button
var view_planet_button: Button
var diplomacy_trade_button: Button
var diplomacy_alliance_button: Button
var diplomacy_war_button: Button

@onready var explore_planet_button: Button = (
	$UI/PlanetViewInfo/MarginContainer/VBoxContainer/ExploreButton
)

var study_planet_button: Button
var exploit_planet_button: Button
var colonize_planet_button: Button
var encountered_civilization: CivilizationData

@onready var simulation_manager: SimulationManager = $SimulationManager

func _ready() -> void:
	stars = galaxy_generator.generate(GALAXY_SEED)
	$SimulationManager.initialize(stars)

	print("Galaxy generated with seed: ", GALAXY_SEED)
	print("Stars generated: ", stars.size())

	# Vue galaxie.
	$Galaxy.set_stars(stars)
	$Galaxy.star_selected.connect(
		_on_star_selected
	)

	# Vue système.
	$System.planet_selected.connect(
		_on_planet_selected
	)

	# Simulation.
	$SimulationManager.year_changed.connect(
		_on_year_changed
	)

	# État initial.
	$UI/StarInfo.visible = false
	$UI/PlanetInfo.visible = false
	$UI/PlanetViewInfo.visible = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$Galaxy.visible = true
	$Galaxy/Camera2D.enabled = true

	# --------------------------------------------------
	# StarInfo
	# --------------------------------------------------

	var star_info_container: VBoxContainer = (
		$UI/StarInfo/MarginContainer/VBoxContainer
	)

	# Bouton de voyage.
	travel_button = Button.new()
	travel_button.text = "Voyager vers ce système"
	travel_button.visible = false
	travel_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	travel_button.pressed.connect(
		_on_travel_button_pressed
	)

	star_info_container.add_child(
		travel_button
	)
	
		# Bouton de commerce.
	diplomacy_trade_button = Button.new()
	diplomacy_trade_button.text = "Proposer un échange"
	diplomacy_trade_button.visible = false
	diplomacy_trade_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	diplomacy_trade_button.pressed.connect(
		_on_diplomacy_trade_button_pressed
	)

	star_info_container.add_child(
		diplomacy_trade_button
	)

	# Bouton d'alliance.
	diplomacy_alliance_button = Button.new()
	diplomacy_alliance_button.text = "Proposer une alliance"
	diplomacy_alliance_button.visible = false
	diplomacy_alliance_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	diplomacy_alliance_button.pressed.connect(
		_on_diplomacy_alliance_button_pressed
	)

	star_info_container.add_child(
		diplomacy_alliance_button
	)

	# Bouton de guerre.
	diplomacy_war_button = Button.new()
	diplomacy_war_button.text = "Déclarer la guerre"
	diplomacy_war_button.visible = false
	diplomacy_war_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	diplomacy_war_button.pressed.connect(
		_on_diplomacy_war_button_pressed
	)

	star_info_container.add_child(
		diplomacy_war_button
	)

	# Bouton d'interaction.
	interaction_button = Button.new()
	interaction_button.text = "Communiquer"
	interaction_button.visible = false
	interaction_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	interaction_button.pressed.connect(
		_on_interaction_button_pressed
	)

	star_info_container.add_child(
		interaction_button
	)

	# --------------------------------------------------
	# PlanetInfo
	# --------------------------------------------------

	var planet_info_container: VBoxContainer = (
		$UI/PlanetInfo/MarginContainer/VBoxContainer
	)

	view_planet_button = Button.new()
	view_planet_button.text = "Explorer cette planète"
	view_planet_button.visible = false
	view_planet_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	view_planet_button.pressed.connect(
		_on_view_planet_button_pressed
	)

	planet_info_container.add_child(
		view_planet_button
	)

	# --------------------------------------------------
	# PlanetViewInfo
	# --------------------------------------------------

	explore_planet_button.text = "Explorer la planète"
	explore_planet_button.visible = true
	explore_planet_button.disabled = false

	explore_planet_button.pressed.connect(
		_on_explore_planet_button_pressed
	)

	var planet_view_info_container: VBoxContainer = (
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer
	)

	# Bouton d'étude.
	study_planet_button = Button.new()
	study_planet_button.text = "Étudier la planète"
	study_planet_button.visible = false
	study_planet_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	study_planet_button.pressed.connect(
		_on_study_planet_button_pressed
	)

	planet_view_info_container.add_child(
		study_planet_button
	)

	# Bouton d'exploitation.
	exploit_planet_button = Button.new()
	exploit_planet_button.text = "Exploiter les ressources"
	exploit_planet_button.visible = false
	exploit_planet_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	exploit_planet_button.pressed.connect(
		_on_exploit_planet_button_pressed
	)

	planet_view_info_container.add_child(
		exploit_planet_button
	)

	# Bouton de colonisation.
	colonize_planet_button = Button.new()
	colonize_planet_button.text = "Coloniser la planète"
	colonize_planet_button.visible = false
	colonize_planet_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	colonize_planet_button.pressed.connect(
		_on_colonize_planet_button_pressed
	)

	planet_view_info_container.add_child(
		colonize_planet_button
	)

	_initialize_player()

func _on_star_selected(star: Dictionary) -> void:
	var star_id: int = int(star["id"])
	var star_type: String = star["type"]
	var star_position: Vector2 = star["position"]
	var system_seed: int = star["system_seed"]

	selected_star = star

	# Sauvegarder l'état de la galaxie.
	galaxy_camera_position = $Galaxy/Camera2D.position
	galaxy_camera_zoom = $Galaxy/Camera2D.zoom

	current_star_id = star_id

	current_system = simulation_manager.get_system(
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

	info += "Seed : "
	info += str(system_seed)
	info += "\n"

	info += "Planètes : "
	info += str(
		current_system["planets"].size()
	)

	if star_id == player.current_system_id:
		info += "\n\n★ Vous êtes ici"

	elif player.traveling and star_id == player.target_system_id:
		info += "\n\nDestination en cours..."

	else:
		var distance: float = (
			player.position.distance_to(
				star_position
			)
		)

		info += "\n\nDistance : "
		info += str(snapped(distance, 1.0))

	_show_star_info(info)

	travel_button.visible = (
		not player.traveling
		and star_id != player.current_system_id
	)

	interaction_button.visible = false

	diplomacy_trade_button.visible = false
	diplomacy_alliance_button.visible = false
	diplomacy_war_button.visible = false

func _on_planet_selected(planet: PlanetData) -> void:
	current_planet = planet

	var info := "PLANÈTE #" + str(planet.id) + "\n\n"

	info += "Type : "
	info += planet.type
	info += "\n"

	info += "Taille : "
	info += str(snapped(planet.size, 0.01))
	info += "\n"

	info += "Température : "
	info += str(snapped(planet.temperature, 0.1))
	info += " °C\n"

	info += "Gravité : "
	info += str(snapped(planet.gravity, 0.01))
	info += " g\n"

	info += "Eau : "
	info += str(snapped(planet.water, 0.1))
	info += " %\n"

	info += "Atmosphère : "
	info += str(snapped(planet.atmosphere, 0.1))
	info += " %\n"

	info += "Habitabilité : "
	info += str(snapped(planet.habitability, 0.1))
	info += " %\n"

	info += "Zone habitable : "
	info += (
		"Oui"
		if planet.in_habitable_zone
		else "Non"
	)

	info += "\n\nLunes : "
	info += str(planet.moon_count)

	if planet.has_life:
		info += "\n\nVie : Oui"
		info += "\nÉvolution : "
		info += planet.life_stage
	else:
		info += "\n\nVie : Aucune"

	if planet.civilization != null:
		info += "\n\nCivilisation : "
		info += planet.civilization.name

		info += "\nPopulation : "
		info += str(planet.population)

		info += "\nCapacité : "
		info += str(planet.population_capacity)

	elif planet.colony != null:
		var colony: ColonyData = planet.colony

		info += "\n\nCOLONIE"

		info += "\nPopulation : "
		info += str(colony.population)

		info += "\nCapacité : "
		info += str(colony.population_capacity)

		info += "\nDéveloppement : "
		info += str(
			snapped(
				colony.development,
				0.1
			)
		)

		info += "\nProduction : "
		info += str(
			snapped(
				colony.production,
				0.1
			)
		)

		info += "\nStabilité : "
		info += str(
			snapped(
				colony.stability,
				0.1
			)
		)

		info += "\nStatut : "
		info += colony.political_status

	elif planet.population > 0:
		info += "\n\nPopulation : "
		info += str(planet.population)

		info += "\nCapacité : "
		info += str(planet.population_capacity)

	var info_label: Label = (
		$UI/PlanetInfo/MarginContainer/VBoxContainer/InfoLabel
	)

	info_label.text = info

	$UI/PlanetInfo.visible = true

	view_planet_button.visible = (
		planet.type != "gas_giant"
	)

func _show_system() -> void:
	$Galaxy.visible = false
	$Galaxy/Camera2D.enabled = false

	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$System.visible = true
	$System/Camera2D.enabled = true

	$UI/StarInfo.visible = false
	$UI/PlanetInfo.visible = false
	$UI/PlanetViewInfo.visible = false

	travel_button.visible = false
	interaction_button.visible = false

	encountered_civilization = (
		_find_civilization_in_system(
			current_system
		)
	)

	current_planet = null

	$System.set_system(current_system)

	if encountered_civilization != null:
		interaction_button.visible = true

func _show_galaxy() -> void:
	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Galaxy.visible = true
	$Galaxy/Camera2D.enabled = true

	$Galaxy/Camera2D.position = player.position
	$Galaxy/Camera2D.zoom = galaxy_camera_zoom

	$UI/StarInfo.visible = false
	$UI/PlanetInfo.visible = false
	$UI/PlanetViewInfo.visible = false

	current_planet = null

	$Galaxy.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed:
			return

		if event.keycode == KEY_SPACE:
			$SimulationManager.simulation_running = (
				not $SimulationManager.simulation_running
			)

		elif event.keycode == KEY_ESCAPE:
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

func _initialize_player() -> void:
	if stars.is_empty():
		return

	var starting_star: Dictionary = {}

	for star in stars:
		var star_id: int = int(star["id"])

		var system: Dictionary = (
			simulation_manager.get_system(
				star_id
			)
		)

		var planets: Array = (
			system.get(
				"planets",
				[]
			)
		)

		var has_civilization := false

		for planet_value in planets:
			if planet_value == null:
				continue

			var planet: PlanetData = planet_value

			if planet.civilization == null:
				continue

			player.civilization_id = (
				planet.civilization.global_id
			)

			has_civilization = true
			break

		if has_civilization:
			starting_star = star
			break

	if starting_star.is_empty():
		starting_star = stars[0]
		player.civilization_id = -1

	player.current_system_id = (
		int(starting_star["id"])
	)

	player.position = (
		starting_star["position"]
	)

	player.current_system_position = (
		starting_star["position"]
	)

	$Galaxy.set_player(player)

	print(
		"Joueur initialisé dans le système #",
		player.current_system_id,
		" | Civilisation #",
		player.civilization_id
	)

func _on_travel_button_pressed() -> void:
	if player.traveling:
		return

	if selected_star.is_empty():
		return

	var target_system_id: int = (
		int(selected_star["id"])
	)

	if target_system_id == player.current_system_id:
		return

	var target_position: Vector2 = (
		selected_star["position"]
	)

	var distance: float = (
		player.position.distance_to(
			target_position
		)
	)

	# Vitesse de déplacement abstraite du vaisseau.
	# 200 unités correspondent à environ une seconde
	# de voyage.
	var travel_speed: float = 200.0

	var travel_duration: float = (
		distance / travel_speed
	)

	player.start_travel(
		target_system_id,
		target_position,
		travel_duration
	)

	travel_button.visible = false

	$UI/StarInfo/MarginContainer/VBoxContainer/InfoLabel.text += (
		"\n\nVoyage en cours..."
	)

	print(
		"Voyage vers le système #",
		target_system_id,
		" | Distance : ",
		snapped(distance, 1.0),
		" | Durée : ",
		snapped(travel_duration, 0.1),
		"s"
	)

func _process(delta: float) -> void:
	if not player.traveling:
		return

	var arrived: bool = (
		player.update_travel(delta)
	)

	if not arrived:
		return

	_on_player_arrived()

func _on_player_arrived() -> void:
	var arrived_system_id: int = (
		player.current_system_id
	)

	current_star_id = arrived_system_id

	current_system = (
		simulation_manager.get_system(
			arrived_system_id
		)
	)

	player.current_system_position = (
		player.position
	)

	selected_star = {}

	travel_button.visible = false

	encountered_civilization = (
		_find_civilization_in_system(
			current_system
		)
	)

	print(
		"Arrivée dans le système #",
		arrived_system_id
	)

	_show_system()

	var info := (
		"Arrivée dans le système #"
		+ str(arrived_system_id)
		+ "\n\n"
		+ "Planètes : "
		+ str(
			current_system.get(
				"planets",
				[]
			).size()
		)
	)

	if encountered_civilization != null:
		info += (
			"\n\n"
			+ "Civilisation détectée : "
			+ encountered_civilization.name
			+ "\n\n"
			+ "Population : "
			+ str(
				encountered_civilization.population
			)
			+ "\n"
			+ "Technologie : "
			+ str(
				snapped(
					encountered_civilization.technology,
					0.1
				)
			)
			+ "\n"
			+ "Économie : "
			+ str(
				snapped(
					encountered_civilization.economy,
					0.1
				)
			)
			+ "\n\n"
			+ "Une civilisation étrangère "
			+ "a détecté votre présence."
		)

	_show_star_info(info)

func _find_civilization_in_system(
	system: Dictionary
) -> CivilizationData:
	var planets: Array = system.get(
		"planets",
		[]
	)

	for planet_value in planets:
		if planet_value == null:
			continue

		var planet: PlanetData = planet_value

		if planet.civilization == null:
			continue

		var civilization: CivilizationData = (
			planet.civilization
		)

		# Ne pas considérer notre propre civilisation
		# comme une rencontre diplomatique.
		if civilization.global_id == player.civilization_id:
			continue

		return civilization

	return null

func _on_interaction_button_pressed() -> void:
	if encountered_civilization == null:
		return

	var civilization: CivilizationData = (
		encountered_civilization
	)

	var relations: Array[RelationData] = (
		simulation_manager.get_civilization_relations(
			civilization.global_id
		)
	)

	var relation_text := "Inconnue"
	var relation_value: float = 0.0
	var trust_value: float = 50.0

	for relation in relations:
		var other_id: int = (
			simulation_manager.get_other_civilization_id(
				relation,
				civilization.global_id
			)
		)

		if other_id != player.civilization_id:
			continue

		relation_text = relation.get_relation_status()
		relation_value = relation.relation
		trust_value = relation.trust
		break

	var info := (
		"COMMUNICATION\n\n"
		+ civilization.name
		+ "\n\n"
		+ "Population : "
		+ str(civilization.population)
		+ "\n"
		+ "Technologie : "
		+ str(
			snapped(
				civilization.technology,
				0.1
			)
		)
		+ "\n"
		+ "Économie : "
		+ str(
			snapped(
				civilization.economy,
				0.1
			)
		)
		+ "\n\n"
		+ "Relation : "
		+ relation_text
		+ "\n"
		+ "Score : "
		+ str(
			snapped(
				relation_value,
				0.1
			)
		)
		+ "\n"
		+ "Confiance : "
		+ str(
			snapped(
				trust_value,
				0.1
			)
		)
		+ "\n\n"
		+ "\"Nous avons détecté votre "
		+ "vaisseau dans notre système.\""
	)

	$UI/StarInfo/MarginContainer/VBoxContainer/InfoLabel.text = info

	interaction_button.text = "Communication établie"
	interaction_button.disabled = true

	# Les actions diplomatiques deviennent visibles.
	diplomacy_trade_button.visible = true
	diplomacy_alliance_button.visible = true
	diplomacy_war_button.visible = true

	# Le commerce est disponible avec une relation
	# suffisamment bonne.
	diplomacy_trade_button.disabled = (
		relation_value < -20.0
	)

	# Une alliance nécessite une bonne relation
	# et une confiance suffisante.
	diplomacy_alliance_button.disabled = (
		relation_value < 40.0
		or trust_value < 50.0
	)

	# La guerre peut toujours être déclarée.
	diplomacy_war_button.disabled = false

func _show_star_info(info: String) -> void:
	var info_label: Label = (
		$UI/StarInfo/MarginContainer/VBoxContainer/InfoLabel
	)

	info_label.text = info

	$UI/StarInfo.visible = true

func _show_planet() -> void:
	$Galaxy.visible = false
	$Galaxy/Camera2D.enabled = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Planet.visible = true
	$Planet/Camera2D.enabled = true

	$UI/StarInfo.visible = true

	travel_button.visible = false
	interaction_button.visible = false

	$Planet.set_planet(current_planet)

func _update_star_info_size() -> void:
	var star_info: Panel = $UI/StarInfo
	var container: MarginContainer = (
		$UI/StarInfo/MarginContainer
	)

	var minimum_size: Vector2 = (
		container.get_combined_minimum_size()
	)

	star_info.custom_minimum_size = Vector2(
		300.0,
		minimum_size.y
	)

	star_info.size = Vector2(
		300.0,
		minimum_size.y
	)

func _on_view_planet_button_pressed() -> void:
	if current_planet == null:
		return

	$UI/PlanetInfo.visible = false
	$UI/PlanetViewInfo.visible = true

	$Galaxy.visible = false
	$Galaxy/Camera2D.enabled = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Planet.visible = true
	$Planet/Camera2D.enabled = true

	$Planet/Camera2D.position = Vector2.ZERO
	$Planet/Camera2D.zoom = Vector2.ONE

	$Planet.set_planet(current_planet)

	var info_label: Label = (
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer/InfoLabel
	)

	var planet: PlanetData = current_planet

	var info: String = (
		planet.type.to_upper()
		+ "\n\n"
	)

	info += "Température : "
	info += str(
		snapped(
			planet.temperature,
			0.1
		)
	)
	info += " °C\n"

	info += "Gravité : "
	info += str(
		snapped(
			planet.gravity,
			0.01
		)
	)
	info += " g\n"

	info += "Eau : "
	info += str(
		snapped(
			planet.water,
			0.1
		)
	)
	info += " %\n"

	info += "Atmosphère : "
	info += str(
		snapped(
			planet.atmosphere,
			0.1
		)
	)
	info += " %\n"

	info += "Habitabilité : "
	info += str(
		snapped(
			planet.habitability,
			0.1
		)
	)
	info += " %\n\n"

	info += "Ressources\n"

	info += "Minéraux : "
	info += str(
		snapped(
			planet.minerals,
			0.1
		)
	)
	info += "\n"

	info += "Énergie : "
	info += str(
		snapped(
			planet.energy,
			0.1
		)
	)
	info += "\n"

	info += "Ressources biologiques : "
	info += str(
		snapped(
			planet.biological_resources,
			0.1
		)
	)
	info += "\n"

	if planet.civilization != null:
		info += "\nCIVILISATION\n"
		info += planet.civilization.name
		info += "\nPopulation : "
		info += str(planet.population)

	elif planet.colony != null:
		var colony: ColonyData = planet.colony

		info += "\nCOLONIE\n"

		info += "Population : "
		info += str(colony.population)
		info += "\n"

		info += "Capacité : "
		info += str(colony.population_capacity)
		info += "\n"

		info += "Développement : "
		info += str(
			snapped(
				colony.development,
				0.1
			)
		)
		info += "\n"

		info += "Production : "
		info += str(
			snapped(
				colony.production,
				0.1
			)
		)
		info += "\n"

		info += "Stabilité : "
		info += str(
			snapped(
				colony.stability,
				0.1
			)
		)
		info += "\n"

		info += "Statut : "
		info += colony.political_status

	elif planet.population > 0:
		info += "\nPopulation : "
		info += str(planet.population)

	info_label.text = info

	explore_planet_button.visible = true
	explore_planet_button.disabled = false
	explore_planet_button.text = "Explorer la planète"

	study_planet_button.visible = false
	study_planet_button.disabled = false
	study_planet_button.text = "Étudier la planète"

	exploit_planet_button.visible = false
	exploit_planet_button.disabled = false
	exploit_planet_button.text = "Exploiter les ressources"

	colonize_planet_button.visible = (
		planet.type != "gas_giant"
		and planet.civilization == null
		and planet.colony == null
		and planet.colony_owner_id == -1
	)

func _on_explore_planet_button_pressed() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	var discovery := ""

	if planet.has_life:
		discovery += (
			"Des signes de vie ont été détectés."
		)

		discovery += "\n\nNiveau d'évolution : "
		discovery += planet.life_stage

		discovery += "\nIndice biologique : "
		discovery += str(
			snapped(planet.life_level, 0.1)
		)

	else:
		discovery += (
			"Aucune forme de vie détectée."
		)

	discovery += "\n\nAnalyse des ressources :"

	discovery += "\nMinéraux : "
	discovery += str(
		snapped(planet.minerals, 0.1)
	)

	discovery += "\nÉnergie : "
	discovery += str(
		snapped(planet.energy, 0.1)
	)

	discovery += "\nRessources biologiques : "
	discovery += str(
		snapped(planet.biological_resources, 0.1)
	)

	if planet.civilization != null:
		discovery += (
			"\n\n⚠ Civilisation intelligente détectée."
		)

		discovery += "\n"
		discovery += planet.civilization.name
	else:
		discovery += (
			"\n\nAucune civilisation intelligente détectée."
		)

	var info_label: Label = (
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer/InfoLabel
	)

	info_label.text = discovery

	explore_planet_button.text = "Planète explorée"
	explore_planet_button.disabled = true

	# Les actions deviennent disponibles.
	study_planet_button.visible = true

	exploit_planet_button.visible = (
		planet.minerals > 0.0
		or planet.energy > 0.0
		or planet.biological_resources > 0.0
	)

	colonize_planet_button.visible = (
		planet.type != "gas_giant"
		and planet.civilization == null
		and planet.colony_owner_id == -1
	)

func _on_study_planet_button_pressed() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	var info := "ÉTUDE SCIENTIFIQUE\n\n"

	info += "La planète présente une habitabilité de "
	info += str(snapped(planet.habitability, 0.1))
	info += " %.\n\n"

	if planet.has_life:
		info += "Des formes de vie sont présentes.\n"
		info += "Niveau : "
		info += planet.life_stage
		info += "\n"

		info += "Complexité biologique : "
		info += str(snapped(planet.life_level, 0.1))
		info += " %\n"

	else:
		info += "Aucune vie détectée.\n"

	if planet.in_habitable_zone:
		info += "\nLa planète se trouve dans la zone habitable."
	else:
		info += "\nLa planète est située hors de la zone habitable."

	var info_label: Label = (
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer/InfoLabel
	)

	info_label.text = info

	study_planet_button.text = "Étude terminée"
	study_planet_button.disabled = true
func _on_exploit_planet_button_pressed() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	var info := "EXPLOITATION DES RESSOURCES\n\n"

	info += "Minéraux disponibles : "
	info += str(snapped(planet.minerals, 0.1))
	info += "\n"

	info += "Énergie disponible : "
	info += str(snapped(planet.energy, 0.1))
	info += "\n"

	info += "Ressources biologiques : "
	info += str(
		snapped(
			planet.biological_resources,
			0.1
		)
	)

	info += "\n\nLes ressources ont été identifiées."

	var info_label: Label = (
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer/InfoLabel
	)

	info_label.text = info

	exploit_planet_button.text = "Ressources identifiées"
	exploit_planet_button.disabled = true
	
func _on_colonize_planet_button_pressed() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	if planet.civilization != null:
		return

	if planet.colony != null:
		return

	if planet.colony_owner_id != -1:
		return

	if planet.type == "gas_giant":
		return

	if planet.habitability < 20.0:
		var info_label: Label = (
			$UI/PlanetViewInfo/MarginContainer/VBoxContainer/InfoLabel
		)

		info_label.text = (
			"COLONISATION IMPOSSIBLE\n\n"
			+ "Cette planète est trop hostile "
			+ "pour établir une colonie."
		)

		return

	var initial_population: int = max(
		100,
		int(planet.population_capacity * 0.01)
	)

	var colony := ColonyData.new()

	colony.initialize(
		player.civilization_id,
		planet.global_id,
		planet
	)

	colony.population = initial_population

	planet.colony = colony
	planet.colony_owner_id = player.civilization_id
	planet.population = initial_population

	var info_label: Label = (
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer/InfoLabel
	)

	info_label.text = (
		"COLONISATION RÉUSSIE\n\n"
		+ "Une nouvelle colonie a été établie "
		+ "sur cette planète."
		+ "\n\n"
		+ "Population initiale : "
		+ str(initial_population)
		+ "\n"
		+ "Capacité : "
		+ str(planet.population_capacity)
		+ "\n"
		+ "Habitabilité : "
		+ str(snapped(planet.habitability, 0.1))
		+ " %"
	)

	colonize_planet_button.text = "Planète colonisée"
	colonize_planet_button.disabled = true

func _on_diplomacy_trade_button_pressed() -> void:
	if encountered_civilization == null:
		return

	var civilization: CivilizationData = (
		encountered_civilization
	)

	var relations: Array[RelationData] = (
		simulation_manager.get_civilization_relations(
			civilization.global_id
		)
	)

	for relation in relations:
		var other_id: int = (
			simulation_manager.get_other_civilization_id(
				relation,
				civilization.global_id
			)
		)

		if other_id != player.civilization_id:
			continue

		if relation.relation < -20.0:
			return

		relation.relation += 5.0
		relation.trust += 3.0

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

		$UI/StarInfo/MarginContainer/VBoxContainer/InfoLabel.text = (
			"ÉCHANGE COMMERCIAL\n\n"
			+ civilization.name
			+ "\n\n"
			+ "La civilisation accepte "
			+ "d'établir des échanges commerciaux."
			+ "\n\n"
			+ "Relation améliorée de +5."
			+ "\n"
			+ "Confiance améliorée de +3."
		)

		diplomacy_trade_button.text = (
			"Échange commercial établi"
		)

		diplomacy_trade_button.disabled = true

		return

func _on_diplomacy_alliance_button_pressed() -> void:
	if encountered_civilization == null:
		return

	var civilization: CivilizationData = (
		encountered_civilization
	)

	var relations: Array[RelationData] = (
		simulation_manager.get_civilization_relations(
			civilization.global_id
		)
	)

	for relation in relations:
		var other_id: int = (
			simulation_manager.get_other_civilization_id(
				relation,
				civilization.global_id
			)
		)

		if other_id != player.civilization_id:
			continue

		if relation.relation < 40.0:
			return

		if relation.trust < 50.0:
			return

		relation.relation += 10.0
		relation.trust += 10.0

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

		$UI/StarInfo/MarginContainer/VBoxContainer/InfoLabel.text = (
			"ALLIANCE\n\n"
			+ civilization.name
			+ "\n\n"
			+ "Une alliance est désormais établie."
			+ "\n\n"
			+ "Relation améliorée de +10."
			+ "\n"
			+ "Confiance améliorée de +10."
		)

		diplomacy_alliance_button.text = (
			"Alliance établie"
		)

		diplomacy_alliance_button.disabled = true

		return

func _on_diplomacy_war_button_pressed() -> void:
	if encountered_civilization == null:
		return

	var civilization: CivilizationData = (
		encountered_civilization
	)

	var relations: Array[RelationData] = (
		simulation_manager.get_civilization_relations(
			civilization.global_id
		)
	)

	for relation in relations:
		var other_id: int = (
			simulation_manager.get_other_civilization_id(
				relation,
				civilization.global_id
			)
		)

		if other_id != player.civilization_id:
			continue

		relation.relation = -100.0
		relation.trust = 0.0

		$UI/StarInfo/MarginContainer/VBoxContainer/InfoLabel.text = (
			"DÉCLARATION DE GUERRE\n\n"
			+ civilization.name
			+ "\n\n"
			+ "Vous avez déclaré la guerre "
			+ "à cette civilisation."
			+ "\n\n"
			+ "Les relations sont désormais hostiles."
		)

		diplomacy_war_button.text = (
			"Guerre déclarée"
		)

		diplomacy_war_button.disabled = true

		return
