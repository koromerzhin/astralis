extends Control

const GALAXY_SEED := 827391

var galaxy_generator := GalaxyGenerator.new()
var stars: Array[Dictionary] = []


func _ready() -> void:
	stars = galaxy_generator.generate(GALAXY_SEED)

	print("Galaxy generated with seed: ", GALAXY_SEED)
	print("Stars generated: ", stars.size())

	$Galaxy.set_stars(stars)
