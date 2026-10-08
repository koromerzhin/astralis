class_name AsteroidBeltData
extends RefCounted


var id: int
var global_id: int
var system_id: int
var seed: int

# Rayon moyen de la ceinture autour de l'étoile et largeur de l'anneau.
var orbit_distance: float
var width: float
var rock_count: int

# Réserve de minéraux, s'épuise par l'exploitation.
var minerals: float
var minerals_initial: float


func initialize(
	belt_id: int,
	belt_seed: int,
	target_system_id: int,
	belt_orbit_distance: float,
	belt_width: float,
	belt_rock_count: int,
	belt_minerals: float
) -> void:
	id = belt_id
	seed = belt_seed
	system_id = target_system_id
	global_id = target_system_id * 1000 + 500 + belt_id
	orbit_distance = belt_orbit_distance
	width = belt_width
	rock_count = belt_rock_count
	minerals = belt_minerals
	minerals_initial = belt_minerals


func is_depleted() -> bool:
	return minerals <= 0.0


# Extraction d'un lot : renvoie la quantité réellement prélevée.
func extract(requested: float) -> float:
	var amount: float = minf(minerals, maxf(requested, 0.0))
	minerals -= amount
	return amount


func to_dict() -> Dictionary:
	return {
		"id": id,
		"global_id": global_id,
		"system_id": system_id,
		"seed": seed,
		"orbit_distance": orbit_distance,
		"width": width,
		"rock_count": rock_count,
		"minerals": minerals,
		"minerals_initial": minerals_initial
	}


func from_dict(data: Dictionary) -> void:
	id = int(data["id"])
	global_id = int(data["global_id"])
	system_id = int(data["system_id"])
	seed = int(data["seed"])
	orbit_distance = float(data["orbit_distance"])
	width = float(data["width"])
	rock_count = int(data["rock_count"])
	minerals = float(data["minerals"])
	minerals_initial = float(
		data.get("minerals_initial", minerals)
	)
