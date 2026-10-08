extends Control

const GALAXY_SEED := 827391
const SAVE_DIR := "user://saves"

static var pending_seed_text := ""
static var pending_civilization_name := ""
static var is_fresh_start := false
static var last_seed_text := ""

var galaxy_seed := GALAXY_SEED

var galaxy_generator := GalaxyGenerator.new()
var main_menu: MainMenu
var _simulation_was_running := false
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
var enter_system_button: Button
var nav_button: Button
var interaction_button: Button
var view_planet_button: Button
var diplomacy_trade_button: Button
var diplomacy_alliance_button: Button
var diplomacy_war_button: Button
var hud: Hud
var planet_list: Panel = null

@onready var explore_planet_button: Button = (
	$UI/PlanetViewInfo/MarginContainer/VBoxContainer/ButtonArea/ExploreButton
)

var study_planet_button: Button
var exploit_planet_button: Button
var colonize_planet_button: Button
var orbit_planet_button: Button
var encountered_civilization: CivilizationData

@onready var simulation_manager: SimulationManager = $SimulationManager

func _ready() -> void:
	galaxy_seed = _consume_pending_seed()
	stars = galaxy_generator.generate(galaxy_seed)
	$SimulationManager.initialize(stars)

	print("Galaxy generated with seed: ", galaxy_seed)
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

	# L'animation céleste suit l'état de la simulation.
	$System.simulation_manager = $SimulationManager
	$Planet.simulation_manager = $SimulationManager

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
		$UI/StarInfo/MarginContainer/VBoxContainer/ButtonArea
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

	# Bouton d'entrée dans le système.
	enter_system_button = Button.new()
	enter_system_button.text = "Entrer dans ce système"
	enter_system_button.visible = false
	enter_system_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	enter_system_button.pressed.connect(
		_on_enter_system_button_pressed
	)

	star_info_container.add_child(
		enter_system_button
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
		$UI/PlanetInfo/MarginContainer/VBoxContainer/ButtonArea
	)

	view_planet_button = Button.new()
	view_planet_button.text = "Voir la planète"
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
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer/ButtonArea
	)

	# Bouton de mise en orbite : obligatoire avant l'exploration.
	orbit_planet_button = Button.new()
	orbit_planet_button.text = "Aller en orbite de la planète"
	orbit_planet_button.visible = false
	orbit_planet_button.custom_minimum_size = Vector2(
		0.0,
		40.0
	)

	orbit_planet_button.pressed.connect(
		_on_orbit_planet_button_pressed
	)

	planet_view_info_container.add_child(orbit_planet_button)
	planet_view_info_container.move_child(orbit_planet_button, 0)

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

	# Bouton de retour (vues système et planète).
	nav_button = Button.new()
	nav_button.text = "Retour galaxie"
	nav_button.visible = false
	nav_button.focus_mode = Control.FOCUS_NONE
	nav_button.custom_minimum_size = Vector2(180.0, 40.0)
	nav_button.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT
	)
	nav_button.offset_left = 20.0
	nav_button.offset_top = 20.0
	nav_button.offset_right = 200.0
	nav_button.offset_bottom = 60.0

	nav_button.pressed.connect(
		_on_nav_button_pressed
	)

	$UI.add_child(nav_button)

	_update_nav_button_position()

	_initialize_player()

	for button in [
		travel_button,
		enter_system_button,
		nav_button,
		interaction_button,
		diplomacy_trade_button,
		diplomacy_alliance_button,
		diplomacy_war_button,
		view_planet_button,
		explore_planet_button,
		orbit_planet_button,
		study_planet_button,
		exploit_planet_button,
		colonize_planet_button,
	]:
		button.focus_mode = Control.FOCUS_NONE

	hud = Hud.new()
	hud.setup(simulation_manager, player)

	$UI.add_child(hud)

	hud.log_toggled.connect(_resize_info_panels)
	get_viewport().size_changed.connect(_resize_info_panels)

	planet_list = preload("res://scripts/ui/system_planet_list.gd").new()
	if planet_list.has_method("setup"):
		planet_list.call("setup", $System)
	$UI.add_child(planet_list)
	planet_list.visible = false
	if not $System.planet_selected.is_connected(planet_list.highlight):
		$System.planet_selected.connect(planet_list.highlight)

	main_menu = MainMenu.new()
	main_menu.new_game_requested.connect(_on_menu_new_game)
	main_menu.continue_requested.connect(_on_menu_continue)
	main_menu.delete_requested.connect(_on_menu_delete)
	main_menu.resume_requested.connect(_on_menu_resume)
	main_menu.save_requested.connect(_on_menu_save)
	main_menu.main_menu_requested.connect(_on_menu_main_menu)
	main_menu.quit_requested.connect(_on_menu_quit)

	$UI.add_child(main_menu)

	var seed_prefill := _seed_prefill()

	main_menu.show_boot(
		list_saves(),
		seed_prefill
	)

	if is_fresh_start:
		is_fresh_start = false
		main_menu.hide()
		_start_on_home_planet()

func _seed_prefill() -> String:
	var seed_prefill := last_seed_text

	if seed_prefill.is_empty():
		seed_prefill = String.num_int64(GALAXY_SEED)

	return seed_prefill

func _consume_pending_seed() -> int:
	var seed_text := pending_seed_text
	pending_seed_text = ""

	if not seed_text.is_empty():
		last_seed_text = seed_text.strip_edges()

	return _resolve_seed(seed_text)


func _resolve_seed(seed_text: String) -> int:
	var text := seed_text.strip_edges()

	if (
		text.is_empty()
		or text == String.num_int64(GALAXY_SEED)
	):
		return GALAXY_SEED

	if text.is_valid_int():
		return int(text)

	return text.hash()


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
		info += "\n" + _ship_location_text(current_system)

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

	enter_system_button.visible = (
		not player.traveling
		and star_id == player.current_system_id
		and $Galaxy.visible
	)

	interaction_button.visible = false

	diplomacy_trade_button.visible = false
	diplomacy_alliance_button.visible = false
	diplomacy_war_button.visible = false

func _on_planet_selected(planet: PlanetData) -> void:
	current_planet = planet

	_set_info_text(
		$UI/PlanetInfo,
		_build_planet_info_text(planet)
	)

	$UI/PlanetInfo.visible = true

	view_planet_button.visible = (
		planet.type != "gas_giant"
	)


func _build_planet_info_text(
	planet: PlanetData
) -> String:
	var info := "PLANÈTE #" + str(planet.id) + "\n\n"

	if player.current_planet_id == planet.global_id:
		info += "★ VAISSEAU PRÉSENT\n\n"

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

	return info

func _show_system() -> void:
	$Galaxy.visible = false
	$Galaxy/Camera2D.enabled = false

	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$System.visible = true
	$System/Camera2D.enabled = true

	var star_id := current_star_id
	if star_id < 0:
		star_id = player.current_system_id

	var star := _find_star_by_id(star_id)
	if not star.is_empty():
		_on_star_selected(star)
	else:
		$UI/StarInfo.visible = false

	$UI/PlanetInfo.visible = false
	$UI/PlanetViewInfo.visible = false

	enter_system_button.visible = false

	nav_button.visible = true
	nav_button.text = "Retour galaxie"

	_update_nav_button_position()

	travel_button.visible = false
	interaction_button.visible = false

	encountered_civilization = (
		_find_civilization_in_system(
			current_system
		)
	)

	current_planet = null

	$System.set_system(current_system)
	_sync_ship_planet()

	if planet_list != null:
		planet_list.visible = true
		planet_list.rebuild($System.planets)

	if encountered_civilization != null:
		interaction_button.visible = true

func _show_galaxy() -> void:
	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$System.visible = false
	$System/Camera2D.enabled = false

	if planet_list != null:
		planet_list.visible = false

	$Galaxy.visible = true
	$Galaxy/Camera2D.enabled = true

	$Galaxy/Camera2D.position = player.position
	$Galaxy/Camera2D.zoom = galaxy_camera_zoom

	$UI/StarInfo.visible = false
	$UI/PlanetInfo.visible = false
	$UI/PlanetViewInfo.visible = false

	enter_system_button.visible = false

	nav_button.visible = false

	current_planet = null

	$Galaxy.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if main_menu != null and main_menu.visible:
		return

	if event is InputEventKey:
		if not event.pressed:
			return

		if event.keycode == KEY_SPACE:
			$SimulationManager.simulation_running = (
				not $SimulationManager.simulation_running
			)

		elif event.keycode == KEY_ESCAPE:
			_open_pause_menu()

func _on_year_changed(year: int) -> void:
	simulation_year = year

	print(
		"Année simulée : ",
		simulation_year
	)

	if current_planet == null:
		return

	if $System.visible and planet_list != null:
		planet_list.refresh_statuses()

	if $Planet.visible:
		_set_info_text(
			$UI/PlanetViewInfo,
			_build_planet_view_text(current_planet)
		)

	elif $System.visible:
		_set_info_text(
			$UI/PlanetInfo,
			_build_planet_info_text(current_planet)
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
	var home_planet: PlanetData = null

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

			home_planet = planet
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

	if home_planet != null:
		current_planet = home_planet
		player.current_planet_id = home_planet.global_id
		home_planet.is_explored = true
		home_planet.is_studied = true

		var chosen_name := _consume_pending_civilization_name()

		if not chosen_name.is_empty() and (
			home_planet.civilization != null
		):
			home_planet.civilization.name = chosen_name

	$Galaxy.set_player(player)

	simulation_manager.player_civilization_id = (
		player.civilization_id
	)

	print(
		"Joueur initialisé dans le système #",
		player.current_system_id,
		" | Civilisation #",
		player.civilization_id
	)

func _consume_pending_civilization_name() -> String:
	var chosen_name := pending_civilization_name.strip_edges()
	pending_civilization_name = ""
	return chosen_name


func _start_on_home_planet() -> void:
	if current_planet == null:
		_show_galaxy()
		return

	current_system = simulation_manager.get_system(
		player.current_system_id
	)

	if current_system.is_empty():
		_show_galaxy()
		return

	_on_view_planet_button_pressed()

func _on_enter_system_button_pressed() -> void:
	if player.traveling:
		return

	current_star_id = player.current_system_id

	current_system = simulation_manager.get_system(
		player.current_system_id
	)

	selected_star = {}

	_show_system()


func _on_nav_button_pressed() -> void:
	if $Planet.visible:
		_show_system()

	elif $System.visible:
		_show_galaxy()
		_restore_star_info(current_star_id)


func _sync_ship_planet() -> void:
	if $System.has_method("set_ship_planet_id"):
		$System.call("set_ship_planet_id", player.current_planet_id)

	if planet_list != null and planet_list.has_method("set_ship_planet_id"):
		planet_list.call("set_ship_planet_id", player.current_planet_id)


func _ship_location_text(system: Dictionary) -> String:
	if player.current_planet_id < 0:
		return "Vaisseau : en orbite de l'étoile"

	var planets: Array = system.get("planets", [])

	for planet_value in planets:
		if planet_value == null:
			continue

		var planet: PlanetData = planet_value

		if planet.global_id == player.current_planet_id:
			return (
				"Vaisseau : sur la planète #"
				+ str(planet.global_id)
			)

	return "Vaisseau : en orbite de l'étoile"


func _find_star_by_id(star_id: int) -> Dictionary:
	if star_id < 0:
		return {}

	for star in stars:
		if int(star["id"]) == star_id:
			return star

	return {}


func _restore_star_info(star_id: int) -> void:
	if star_id < 0:
		return

	for star in stars:
		if int(star["id"]) == star_id:
			_on_star_selected(star)
			return


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
	enter_system_button.visible = false

	var travel_info: String = (
		$UI/StarInfo/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel.text
		+ "\n\nVoyage en cours..."
	)

	_set_info_text($UI/StarInfo, travel_info)

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

	# Le vaisseau arrive en orbite de l'étoile, sur aucune planète.
	player.current_planet_id = -1

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

	if hud != null:
		hud.add_event(
			"Arrivée dans le système #"
			+ str(arrived_system_id),
			true
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
		+ "\n"
		+ _ship_location_text(current_system)
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

	_set_info_text($UI/StarInfo, info)

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
	_set_info_text($UI/StarInfo, info)

	$UI/StarInfo.visible = true

	_update_nav_button_position()


func _set_info_text(panel: Panel, text: String) -> void:
	var info_label: Label = (
		panel.get_node(
			"MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel"
		)
	)

	info_label.text = text

	_queue_info_resize(panel)


var _pending_info_resizes: Dictionary = {}


func _queue_info_resize(panel: Panel) -> void:
	if _pending_info_resizes.has(panel):
		return

	_pending_info_resizes[panel] = true

	call_deferred("_resize_info_async", panel)


func _resize_info_async(panel: Panel) -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_pending_info_resizes.erase(panel)

	if not is_instance_valid(panel):
		return

	if not panel.visible:
		return

	var scroll_content: Control = panel.get_node(
		"MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer"
	)

	var footer: Control = panel.get_node(
		"MarginContainer/VBoxContainer/ButtonArea"
	)

	var content_height: float = (
		scroll_content.size.y
		+ footer.size.y
		+ 34.0
	)

	var max_height: float = _get_info_panel_max_height(panel)

	panel.size.y = clampf(
		content_height,
		120.0,
		max_height
	)

	_update_nav_button_position()


func _update_nav_button_position() -> void:
	if nav_button == null:
		return

	var top := 20.0

	if $UI/StarInfo.visible:
		top = (
			$UI/StarInfo.position.y
			+ $UI/StarInfo.size.y
			+ 12.0
		)

	nav_button.offset_top = top
	nav_button.offset_bottom = top + 40.0


func _resize_info_panels() -> void:
	for panel: Panel in [
		$UI/StarInfo,
		$UI/PlanetInfo,
		$UI/PlanetViewInfo,
	]:
		if panel.visible:
			_queue_info_resize(panel)


func _get_info_panel_max_height(panel: Panel) -> float:
	if hud == null:
		return 400.0

	var viewport_height: float = (
		get_viewport_rect().size.y
	)

	if (
		panel == $UI/PlanetInfo
		or panel == $UI/PlanetViewInfo
	):
		var available: float = (
			viewport_height
			- hud.get_reserved_bottom_height()
			- 26.0
		)

		return maxf(120.0, available)

	return maxf(120.0, viewport_height - 88.0 - 26.0)

func _on_view_planet_button_pressed() -> void:
	if current_planet == null:
		return

	$UI/PlanetInfo.visible = false
	$UI/PlanetViewInfo.visible = true

	nav_button.visible = true
	nav_button.text = "Retour système"

	if planet_list != null:
		planet_list.visible = false

	_update_nav_button_position()

	$Galaxy.visible = false
	$Galaxy/Camera2D.enabled = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Planet.visible = true
	$Planet/Camera2D.enabled = true

	$Planet/Camera2D.position = Vector2.ZERO
	$Planet/Camera2D.zoom = Vector2.ONE

	var planet: PlanetData = current_planet

	$Planet.set_planet(planet)
	$Planet.set_ship_in_orbit(
		player.current_planet_id == planet.global_id
	)

	_refresh_planet_view_text()
	_refresh_planet_action_buttons()


func _refresh_planet_view_text() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	# Une planète colonisée est connue : exploration et étude effectuées,
	# même si les drapeaux manquent (sauvegardes anciennes).
	var known: bool = (
		planet.is_explored
		or planet.colony != null
	)
	var studied: bool = (
		planet.is_studied
		or planet.colony != null
	)

	var info: String = _build_planet_view_text(planet)

	if known:
		info += "\n\n" + _build_exploration_text(planet)

	if studied:
		info += "\n\n" + _build_study_text(planet)

	_set_info_text(
		$UI/PlanetViewInfo,
		info
	)


func _refresh_planet_action_buttons() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	var known: bool = (
		planet.is_explored
		or planet.colony != null
	)
	var studied: bool = (
		planet.is_studied
		or planet.colony != null
	)
	var in_orbit: bool = (
		player.current_planet_id == planet.global_id
	)

	# Il faut d'abord se mettre en orbite autour de la planète.
	orbit_planet_button.visible = not in_orbit
	orbit_planet_button.disabled = false
	orbit_planet_button.text = (
		"Aller en orbite de la planète"
	)

	explore_planet_button.visible = true
	explore_planet_button.disabled = known or not in_orbit
	explore_planet_button.text = (
		"Planète explorée"
		if known
		else "Explorer la planète"
	)
	explore_planet_button.tooltip_text = (
		""
		if known or in_orbit
		else "Le vaisseau doit être en orbite "
		+ "autour de la planète"
	)

	study_planet_button.visible = known
	study_planet_button.disabled = studied
	study_planet_button.text = (
		"Étude terminée"
		if studied
		else "Étudier la planète"
	)

	exploit_planet_button.visible = (
		known
		and (
			planet.minerals > 0.0
			or planet.energy > 0.0
			or planet.biological_resources > 0.0
		)
	)
	exploit_planet_button.disabled = false
	exploit_planet_button.text = "Exploiter les ressources"

	colonize_planet_button.visible = (
		planet.type != "gas_giant"
		and planet.civilization == null
		and planet.colony == null
		and planet.colony_owner_id == -1
	)


func _on_orbit_planet_button_pressed() -> void:
	if current_planet == null:
		return

	# Le vaisseau se place en orbite autour de la planète.
	player.current_planet_id = current_planet.global_id
	_sync_ship_planet()
	$Planet.set_ship_in_orbit(true)

	if planet_list != null:
		planet_list.refresh_statuses()

	_refresh_planet_view_text()
	_refresh_planet_action_buttons()


func _build_planet_view_text(
	planet: PlanetData
) -> String:
	var info: String = (
		planet.type.to_upper()
		+ "\n\n"
	)

	if player.current_planet_id == planet.global_id:
		info += "★ VAISSEAU PRÉSENT\n\n"
	else:
		info += (
			"Vaisseau : hors orbite\n"
			+ "(aller en orbite pour explorer)\n\n"
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

		if planet.colony != null:
			var home_colony: ColonyData = planet.colony

			info += "\n\nCOLONIE\n"

			info += "Capacité : "
			info += str(
				home_colony.population_capacity
			)
			info += "\n"

			info += "Développement : "
			info += str(
				snapped(
					home_colony.development,
					0.1
				)
			)
			info += "\n"

			info += "Production : "
			info += str(
				snapped(
					home_colony.production,
					0.1
				)
			)
			info += "\n"

			info += "Stabilité : "
			info += str(
				snapped(
					home_colony.stability,
					0.1
				)
			)
			info += "\n"

			info += "Statut : "
			info += home_colony.political_status

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

	return info

func _on_explore_planet_button_pressed() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	planet.is_explored = true

	_set_info_text(
		$UI/PlanetViewInfo,
		_build_exploration_text(planet)
	)

	# Les actions deviennent disponibles.
	_refresh_planet_action_buttons()

	if $System.visible and planet_list != null:
		planet_list.refresh_statuses()

func _build_exploration_text(
	planet: PlanetData
) -> String:
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

	return discovery

func _on_study_planet_button_pressed() -> void:
	if current_planet == null:
		return

	var planet: PlanetData = current_planet

	planet.is_studied = true

	_set_info_text(
		$UI/PlanetViewInfo,
		_build_study_text(planet)
	)

	study_planet_button.text = "Étude terminée"
	study_planet_button.disabled = true

	if $System.visible and planet_list != null:
		planet_list.refresh_statuses()

func _build_study_text(
	planet: PlanetData
) -> String:
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

	return info
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
		$UI/PlanetViewInfo/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
	)

	_set_info_text($UI/PlanetViewInfo, info)

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
		_set_info_text(
			$UI/PlanetViewInfo,
			(
				"COLONISATION IMPOSSIBLE\n\n"
				+ "Cette planète est trop hostile "
				+ "pour établir une colonie."
			)
		)

		return

	var initial_population: int = max(
		100,
		int(planet.population_capacity * 0.01)
	)

	var player_civilization: CivilizationData = (
		simulation_manager.get_civilization(
			player.civilization_id
		)
	)

	if player_civilization == null:
		return

	player_civilization.add_colony(
		planet.global_id,
		planet
	)

	var colony: ColonyData = planet.colony

	if colony == null:
		return

	colony.population = initial_population

	planet.population = initial_population

	_set_info_text(
		$UI/PlanetViewInfo,
		(
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
	)

	colonize_planet_button.text = "Planète colonisée"
	colonize_planet_button.disabled = true

	if hud != null:
		hud.add_event(
			"Colonisation de la planète #"
			+ str(planet.global_id)
			+ " dans le système #"
			+ str(player.current_system_id),
			true
		)

	simulation_manager.register_planet_control(
		player.civilization_id,
		planet.global_id,
		player.current_system_id
	)

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

		_set_info_text(
			$UI/StarInfo,
			(
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

		_set_info_text(
			$UI/StarInfo,
			(
				"ALLIANCE\n\n"
				+ civilization.name
				+ "\n\n"
				+ "Une alliance est désormais établie."
				+ "\n\n"
				+ "Relation améliorée de +10."
				+ "\n"
				+ "Confiance améliorée de +10."
			)
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

		_set_info_text(
			$UI/StarInfo,
			(
				"DÉCLARATION DE GUERRE\n\n"
				+ civilization.name
				+ "\n\n"
				+ "Vous avez déclaré la guerre "
				+ "à cette civilisation."
				+ "\n\n"
				+ "Les relations sont désormais hostiles."
			)
		)

		diplomacy_war_button.text = (
			"Guerre déclarée"
		)

		diplomacy_war_button.disabled = true

		return


func _open_pause_menu() -> void:
	_simulation_was_running = (
		$SimulationManager.simulation_running
	)

	$SimulationManager.simulation_running = false

	main_menu.show_pause()


func _on_menu_new_game(
	seed_text: String,
	civilization_name: String
) -> void:
	pending_seed_text = seed_text.strip_edges()
	pending_civilization_name = civilization_name
	is_fresh_start = true

	get_tree().reload_current_scene()


func _on_menu_continue(save_key: String) -> void:
	if save_key.is_empty():
		return

	if load_game(save_key):
		main_menu.hide()


func _on_menu_delete(save_key: String) -> void:
	if not delete_save(save_key):
		return

	var saves := list_saves()

	if saves.is_empty():
		main_menu.show_boot(
			saves,
			_seed_prefill()
		)
	else:
		main_menu.refresh_saves(saves)


func _on_menu_resume() -> void:
	main_menu.hide()

	$SimulationManager.simulation_running = (
		_simulation_was_running
	)


func _on_menu_save() -> void:
	if save_game():
		main_menu.refresh_save_state(
			not list_saves().is_empty()
		)


func _on_menu_main_menu() -> void:
	get_tree().reload_current_scene()


func _on_menu_quit() -> void:
	get_tree().quit()


func save_game(save_key: String = "") -> bool:
	_ensure_save_dir()

	if save_key.is_empty():
		save_key = _save_key_for_current_game()

	var save_path := SAVE_DIR + "/" + save_key + ".dat"

	var payload := {
		"version": 2,
		"saved_at": Time.get_datetime_string_from_system(),
		"civilization_name": _current_civilization_name(),
		"seed": galaxy_seed,
		"save_key": save_key,
		"player": player.to_dict(),
		"simulation": simulation_manager.save_to_dict()
	}

	var file := FileAccess.open(
		save_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Impossible d'ouvrir la sauvegarde : "
			+ save_path
		)

		return false

	file.store_string(
		var_to_str(payload)
	)

	file.close()

	if hud != null:
		hud.refresh()

	return true


func load_game(save_key: String) -> bool:
	var save_path := SAVE_DIR + "/" + save_key + ".dat"

	if not FileAccess.file_exists(save_path):
		return false

	var file := FileAccess.open(
		save_path,
		FileAccess.READ
	)

	if file == null:
		return false

	var parsed = str_to_var(
		file.get_as_text()
	)

	file.close()

	if parsed == null or not parsed is Dictionary:
		return false

	var simulation_data: Dictionary = parsed["simulation"]

	simulation_manager.load_from_dict(
		simulation_data
	)

	player.from_dict(parsed["player"])

	galaxy_seed = int(
		parsed.get(
			"seed",
			GALAXY_SEED
		)
	)

	_refresh_after_load()

	if hud != null:
		hud.refresh()

	return true


func list_saves() -> Array:
	_ensure_save_dir()

	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)

	if dir == null:
		return result

	dir.list_dir_begin()

	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and (
			file_name.ends_with(".dat")
		):
			var save_key := file_name.trim_suffix(".dat")
			var save_meta := _read_save_meta(
				save_key
			)

			if save_meta != null:
				result.append(save_meta)

		file_name = dir.get_next()

	dir.list_dir_end()
	return result


func delete_save(save_key: String) -> bool:
	var save_path := SAVE_DIR + "/" + save_key + ".dat"

	if not FileAccess.file_exists(save_path):
		return false

	return (
		DirAccess.remove_absolute(save_path)
		== OK
	)


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _save_key_for_current_game() -> String:
	if player.civilization_id < 0:
		return "civilisation"

	var raw_key := (
		_current_civilization_name()
		+ "|"
		+ str(galaxy_seed)
	)

	return str(abs(raw_key.hash()))


func _current_civilization_name() -> String:
	var civilization := simulation_manager.get_civilization(
		player.civilization_id
	)

	if civilization == null:
		return "Civilisation"

	return civilization.name


func _read_save_meta(save_key: String) -> Dictionary:
	var save_path := SAVE_DIR + "/" + save_key + ".dat"
	var file := FileAccess.open(
		save_path,
		FileAccess.READ
	)

	if file == null:
		return {}

	var parsed = str_to_var(
		file.get_as_text()
	)

	file.close()

	if parsed == null or not parsed is Dictionary:
		return {}

	return {
		"key": save_key,
		"name": str(
			parsed.get(
				"civilization_name",
				"Sans nom"
			)
		),
		"seed": int(
			parsed.get(
				"seed",
				GALAXY_SEED
			)
		),
		"saved_at": str(
			parsed.get(
				"saved_at",
				""
			)
		)
	}


func _stars_from_simulation() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for system_key in simulation_manager._systems.keys():
		var system: Dictionary = (
			simulation_manager._systems[int(system_key)]
		)

		result.append(
			{
				"id": int(system_key),
				"type": system.get(
					"star_type",
					""
				),
				"position": system.get(
					"position",
					Vector2.ZERO
				),
				"system_seed": system.get(
					"seed",
					0
				)
			}
		)

	return result


func _refresh_after_load() -> void:
	current_star_id = -1
	current_system = {}
	current_planet = null
	selected_star = {}
	encountered_civilization = null
	simulation_year = simulation_manager.current_year

	stars = _stars_from_simulation()

	$Galaxy.set_stars(stars)
	$Galaxy.queue_redraw()

	_show_galaxy()
	_sync_ship_planet()
