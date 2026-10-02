class_name GalaxyGenerator
extends RefCounted

const STAR_COUNT := 100

func generate(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var stars: Array[Dictionary] = []

	for i in STAR_COUNT:
		stars.append({
			"id": i,
			"position": Vector2(
				rng.randf_range(-1000.0, 1000.0),
				rng.randf_range(-600.0, 600.0)
			),
			"type": _generate_star_type(rng),
		})

	return stars


func _generate_star_type(rng: RandomNumberGenerator) -> String:
	var types := [
		"red_dwarf",
		"yellow",
		"orange",
		"blue",
		"white"
	]

	return types[rng.randi_range(0, types.size() - 1)]
