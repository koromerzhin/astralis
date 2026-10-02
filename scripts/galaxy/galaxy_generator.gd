class_name GalaxyGenerator
extends RefCounted

const STAR_COUNT := 1500

const GALAXY_RADIUS := 1200.0
const ARM_COUNT := 4
const ARM_TWIST := 2.5
const ARM_SPREAD := 0.35
const CORE_RADIUS := 180.0


func generate(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var stars: Array[Dictionary] = []

	for i in STAR_COUNT:
		var star := _generate_star(rng, i)
		stars.append(star)

	return stars


func _generate_star(rng: RandomNumberGenerator, id: int) -> Dictionary:
	var radius := _generate_radius(rng)
	var angle := _generate_angle(rng, radius)

	var position := Vector2(
		cos(angle) * radius,
		sin(angle) * radius
	)

	return {
		"id": id,
		"position": position,
		"type": _generate_star_type(rng),
		"system_seed": rng.randi(),
	}


func _generate_radius(rng: RandomNumberGenerator) -> float:
	var value := rng.randf()

	# Une partie importante des étoiles reste proche du centre.
	if value < 0.25:
		return rng.randf_range(0.0, CORE_RADIUS)

	return sqrt(value) * GALAXY_RADIUS


func _generate_angle(rng: RandomNumberGenerator, radius: float) -> float:
	var arm := rng.randi_range(0, ARM_COUNT - 1)

	var base_angle := TAU * float(arm) / ARM_COUNT

	var spiral_angle := radius / GALAXY_RADIUS * ARM_TWIST * TAU

	var spread := rng.randf_range(-ARM_SPREAD, ARM_SPREAD)

	return base_angle + spiral_angle + spread


func _generate_star_type(rng: RandomNumberGenerator) -> String:
	var types := [
		"red_dwarf",
		"yellow",
		"orange",
		"blue",
		"white"
	]

	return types[rng.randi_range(0, types.size() - 1)]
