extends Control


const GALAXY_SEED := 827391


var galaxy_generator := GalaxyGenerator.new()
var system_generator := SystemGenerator.new()

var stars: Array[Dictionary] = []

var galaxy_camera_position := Vector2.ZERO
var galaxy_camera_zoom := Vector2.ONE

var current_star_id := -1
var current_system: Dictionary = {}
var current_planet: PlanetData


func _ready() -> void:
	stars = galaxy_generator.generate(GALAXY_SEED)

	print("Galaxy generated with seed: ", GALAXY_SEED)
	print("Stars generated: ", stars.size())

	$Galaxy.set_stars(stars)
	$Galaxy.star_selected.connect(_on_star_selected)
	$System.planet_selected.connect(_on_planet_selected)

	$StarInfo.visible = false

	$System.visible = false
	$System/Camera2D.enabled = false

	$Planet.visible = false
	$Planet/Camera2D.enabled = false

	$Galaxy.visible = true
	$Galaxy/Camera2D.enabled = true


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
	current_system = system_generator.generate(
		system_seed,
		star_type
	)

	var info := "Système #" + str(star_id) + "\n\n"
	info += "Type : " + star_type + "\n"
	info += "Position : " + str(round(star_position.x))
	info += ", " + str(round(star_position.y)) + "\n"
	info += "Seed : " + str(system_seed) + "\n"
	info += "Planètes : " + str(current_system["planets"].size())

	$StarInfo/InfoLabel.text = info

	_show_system()


func _on_planet_selected(planet: PlanetData) -> void:
	current_planet = planet

	var info := "Planète #" + str(planet.id) + "\n\n"
	info += "Type : " + planet.type + "\n"
	info += "Taille : " + str(planet.size) + "\n"
	info += "Distance : " + str(round(planet.orbit_distance)) + "\n"
	info += "Lunes : " + str(planet.moon_count) + "\n"
	info += "Seed : " + str(planet.seed)

	$StarInfo/InfoLabel.text = info
	$StarInfo.visible = true

	$System.visible = false
	$System/Camera2D.enabled = false

	$Planet.visible = true
	$Planet/Camera2D.enabled = true

	$Planet.set_planet(planet)


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

	$Galaxy/Camera2D.position = galaxy_camera_position
	$Galaxy/Camera2D.zoom = galaxy_camera_zoom

	$StarInfo.visible = false

	$Galaxy.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if $Planet.visible:
				_show_system()

			elif $System.visible:
				_show_galaxy()
