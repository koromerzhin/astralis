extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var sim: SimulationManager = main.simulation_manager
	sim.simulation_running = false

	if main.current_planet == null:
		push_error("planete mere absente")
		quit()
		return

	var c0: int = sim._civilizations.size()
	var planets0: int = sim._colonizable_planets.size()

	for i in range(6):
		sim._advance_year()

	if sim.current_year != 6:
		push_error("annee attendue 6, eu " + str(sim.current_year))
		quit()
		return

	if sim._civilizations.size() == 0:
		push_error("civilisations disparues")
		quit()
		return

	if sim._colonizable_planets.size() >= planets0:
		push_error("colonisation inactive: " + str(planets0) + " -> " + str(sim._colonizable_planets.size()))
		quit()
		return

	var total_colonies: int = 0
	for civ_id in sim._civilizations.keys():
		var civ: CivilizationData = sim._civilizations[civ_id]
		if civ != null:
			total_colonies += civ.colonies.size()

	if total_colonies == 0:
		push_error("aucune colonie creee en 6 ans")
		quit()
		return

	var claim_count: int = 0
	for civ_id in sim._civilization_territorial_claims.keys():
		var claims: Dictionary = sim._civilization_territorial_claims[civ_id]
		claim_count += claims.size()
	if claim_count == 0:
		push_error("aucune revendication territoriale")
		quit()
		return

	var influence_entries: int = 0
	for sys in sim._civilization_system_influence.values():
		influence_entries += sys.size()
	if influence_entries == 0:
		push_error("aucune influence")
		quit()
		return

	var player_civ: CivilizationData = sim.get_civilization(main.player.civilization_id)
	if player_civ == null or player_civ.colonies.is_empty():
		push_error("civilisation joueur sans colonie")
		quit()
		return

	var test_save_key: String = "perf_test_save_zq23"

	if not main.save_game(test_save_key):
		push_error("save_game a echoue")
		quit()
		return

	if not main.load_game(test_save_key):
		push_error("load_game a echoue")
		quit()
		return

	if sim.get_civilization(main.player.civilization_id) == null:
		push_error("civilisation joueur perdue au load")
		quit()
		return

	main.delete_save(test_save_key)

	print("TEST OK - colonies=", total_colonies, " claims=", claim_count, " influence=", influence_entries)
	quit()