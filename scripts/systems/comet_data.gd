class_name CometData
extends RefCounted


var id: int
var global_id: int
var system_id: int
var seed: int

# Orbite elliptique : l'étoile occupe le foyer.
var semi_major: float
var eccentricity: float
var phase: float
var angular_speed: float
var size: float

# Les ressources volatiles ne peuvent être extraites qu'une fois.
var extracted: bool = false


func initialize(
	comet_id: int,
	comet_seed: int,
	target_system_id: int,
	comet_semi_major: float,
	comet_eccentricity: float,
	comet_phase: float,
	comet_size: float
) -> void:
	id = comet_id
	seed = comet_seed
	system_id = target_system_id
	global_id = target_system_id * 1000 + 900 + comet_id
	semi_major = comet_semi_major
	eccentricity = comet_eccentricity
	phase = comet_phase
	size = comet_size

	# Période de Kepler approchée : plus l'orbite est grande,
	# plus la comète est lente.
	angular_speed = 283.0 / pow(maxf(semi_major, 1.0), 1.5)


func is_depleted() -> bool:
	return extracted


# Période orbitale approximative, en secondes de jeu.
func get_period() -> float:
	if angular_speed <= 0.0:
		return 0.0

	return TAU / angular_speed


# Périhélie : distance minimale à l'étoile.
func get_perihelion() -> float:
	return semi_major * (1.0 - eccentricity)


func get_position(theta: float) -> Vector2:
	var a := semi_major
	var e := eccentricity
	var b := a * sqrt(maxf(1.0 - e * e, 0.0001))

	return Vector2(
		a * cos(theta) - a * e,
		b * sin(theta)
	)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"global_id": global_id,
		"system_id": system_id,
		"seed": seed,
		"semi_major": semi_major,
		"eccentricity": eccentricity,
		"phase": phase,
		"angular_speed": angular_speed,
		"size": size,
		"extracted": extracted
	}


func from_dict(data: Dictionary) -> void:
	id = int(data["id"])
	global_id = int(data["global_id"])
	system_id = int(data["system_id"])
	seed = int(data["seed"])
	semi_major = float(data["semi_major"])
	eccentricity = float(data["eccentricity"])
	phase = float(data["phase"])
	angular_speed = float(data["angular_speed"])
	size = float(data["size"])
	extracted = bool(data.get("extracted", false))
