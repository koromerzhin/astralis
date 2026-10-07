extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var sim: SimulationManager = main.simulation_manager
	sim.simulation_running = false

	for i in range(8):
		var before := Time.get_ticks_usec()
		sim._advance_year()
		var after := Time.get_ticks_usec()
		print("CALL_CLOCK_MS=", (after - before) / 1000.0)

	quit()