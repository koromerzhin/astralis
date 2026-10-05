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
