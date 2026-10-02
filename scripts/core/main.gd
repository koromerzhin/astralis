extends Control

const GALAXY_SEED := 827391

var galaxy_generator := GalaxyGenerator.new()
var system_generator := SystemGenerator.new()
var stars: Array[Dictionary] = []

func _show_system(system: Dictionary) -> void:
	$Galaxy.visible = false
	$Galaxy/Camera2D.enabled = false

	$StarInfo.visible = false

	$System.visible = true
	$System/Camera2D.enabled = true

	$System.set_system(system)

func _ready() -> void:
	stars = galaxy_generator.generate(GALAXY_SEED)

	print("Galaxy generated with seed: ", GALAXY_SEED)
	print("Stars generated: ", stars.size())

	$Galaxy.set_stars(stars)
	$Galaxy.star_selected.connect(_on_star_selected)

	$System.planet_selected.connect(_on_planet_selected)

	$System.visible = false
	$System/Camera2D.enabled = false


func _on_star_selected(star: Dictionary) -> void:
	var star_id: int = star["id"]
	var star_type: String = star["type"]
	var star_position: Vector2 = star["position"]
	var system_seed: int = star["system_seed"]

	var system: Dictionary = system_generator.generate(
		system_seed,
		star_type
	)

	var info := "Système #" + str(star_id) + "\n\n"
	info += "Type : " + star_type + "\n"
	info += "Position : " + str(round(star_position.x))
	info += ", " + str(round(star_position.y)) + "\n"
	info += "Seed : " + str(system_seed) + "\n"
	info += "Planètes : " + str(system["planets"].size())

	$StarInfo/InfoLabel.text = info

	_show_system(system)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_show_galaxy()


func _show_galaxy() -> void:
	$System.visible = false
	$System/Camera2D.enabled = false

	$StarInfo.visible = false

	$Galaxy.visible = true
	$Galaxy/Camera2D.enabled = true

func _on_planet_selected(planet: PlanetData) -> void:
	var info := "Planète #" + str(planet.id) + "\n\n"
	info += "Type : " + planet.type + "\n"
	info += "Taille : " + str(planet.size) + "\n"
	info += "Distance : " + str(round(planet.orbit_distance)) + "\n"
	info += "Lunes : " + str(planet.moon_count) + "\n"
	info += "Seed : " + str(planet.seed)

	$StarInfo/InfoLabel.text = info
	$StarInfo.visible = true
