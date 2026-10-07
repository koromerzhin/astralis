class_name PlayerData
extends RefCounted

var civilization_id: int = -1
var current_system_id: int = -1
var target_system_id: int = -1

var position: Vector2 = Vector2.ZERO
var current_system_position: Vector2 = Vector2.ZERO
var travel_start_position: Vector2 = Vector2.ZERO
var travel_target_position: Vector2 = Vector2.ZERO

var traveling: bool = false
var travel_progress: float = 0.0
var travel_duration: float = 0.0

func start_travel(
	target_id: int,
	target_position: Vector2,
	duration: float
) -> void:
	target_system_id = target_id

	travel_start_position = position
	travel_target_position = target_position

	travel_duration = max(
		duration,
		0.01
	)

	travel_progress = 0.0
	traveling = true

func update_travel(delta: float) -> bool:
	if not traveling:
		return false

	travel_progress += delta / travel_duration

	if travel_progress >= 1.0:
		travel_progress = 1.0
		position = travel_target_position
		current_system_id = target_system_id
		target_system_id = -1
		traveling = false
		return true

	position = travel_start_position.lerp(
		travel_target_position,
		travel_progress
	)

	return false


func to_dict() -> Dictionary:
	return {
		"civilization_id": civilization_id,
		"current_system_id": current_system_id,
		"target_system_id": target_system_id,
		"position": {"x": position.x, "y": position.y},
		"current_system_position": {"x": current_system_position.x, "y": current_system_position.y},
		"travel_start_position": {"x": travel_start_position.x, "y": travel_start_position.y},
		"travel_target_position": {"x": travel_target_position.x, "y": travel_target_position.y},
		"traveling": traveling,
		"travel_progress": travel_progress,
		"travel_duration": travel_duration
	}


func from_dict(data: Dictionary) -> void:
	civilization_id = data["civilization_id"]
	current_system_id = data["current_system_id"]
	target_system_id = data["target_system_id"]
	position = _vec(data, "position")
	current_system_position = _vec(data, "current_system_position")
	travel_start_position = _vec(data, "travel_start_position")
	travel_target_position = _vec(data, "travel_target_position")
	traveling = data["traveling"]
	travel_progress = data["travel_progress"]
	travel_duration = data["travel_duration"]


func _vec(data: Dictionary, key: String) -> Vector2:
	var value: Dictionary = data[key]

	if value is Dictionary and value.has("x") and value.has("y"):
		return Vector2(
			value["x"],
			value["y"]
		)

	return Vector2.ZERO
