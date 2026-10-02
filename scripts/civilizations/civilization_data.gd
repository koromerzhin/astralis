class_name CivilizationData
extends RefCounted


var id: int
var seed: int

var name: String

var population: int

var technology: float
var economy: float
var space_capability: float

var age: float

var home_planet_id: int


func initialize(
	civilization_id: int,
	civilization_seed: int,
	planet_id: int
) -> void:
	id = civilization_id
	seed = civilization_seed
	home_planet_id = planet_id

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	name = _generate_name(rng)

	population = rng.randi_range(
		100000,
		10000000
	)

	technology = rng.randf_range(
		1.0,
		50.0
	)

	economy = rng.randf_range(
		1.0,
		50.0
	)

	age = rng.randf_range(
		100.0,
		10000.0
	)

	space_capability = _calculate_space_capability()


func _calculate_space_capability() -> float:
	var capability: float = 0.0

	# La technologie est le facteur principal.
	capability += technology * 1.5

	# Une économie forte facilite le développement spatial.
	capability += economy * 0.5

	# Une civilisation ancienne a eu davantage
	# de temps pour développer ses capacités.
	capability += min(age / 500.0, 20.0)

	return clamp(
		capability,
		0.0,
		100.0
	)


func _generate_name(rng: RandomNumberGenerator) -> String:
	var prefixes := [
		"Al",
		"Ka",
		"Zor",
		"Vel",
		"Tar",
		"Kor",
		"Xan",
		"Mer",
		"Sol",
		"Nex"
	]

	var suffixes := [
		"ia",
		"on",
		"ar",
		"us",
		"ea",
		"or",
		"is",
		"an"
	]

	var prefix: String = prefixes[
		rng.randi_range(
			0,
			prefixes.size() - 1
		)
	]

	var suffix: String = suffixes[
		rng.randi_range(
			0,
			suffixes.size() - 1
		)
	]

	return prefix + suffix

func get_space_stage() -> String:
	if space_capability < 20.0:
		return "planetary"

	if space_capability < 50.0:
		return "orbital"

	if space_capability < 75.0:
		return "interplanetary"

	return "interstellar"
