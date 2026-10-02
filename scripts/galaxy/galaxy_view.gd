extends Node2D

var stars: Array[Dictionary] = []

@export var move_speed := 500.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.25
@export var max_zoom := 4.0

@onready var camera: Camera2D = $Camera2D


func set_stars(new_stars: Array[Dictionary]) -> void:
	stars = new_stars
	queue_redraw()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S):
		direction.y += 1

	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D):
		direction.x += 1

	if direction != Vector2.ZERO:
		camera.position += direction.normalized() * move_speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom(1.0 - zoom_speed)

			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(1.0 + zoom_speed)


func _zoom(factor: float) -> void:
	var new_zoom := camera.zoom.x * factor
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)

	camera.zoom = Vector2(new_zoom, new_zoom)


func _draw() -> void:
	for star in stars:
		var position: Vector2 = star["position"]

		draw_circle(position, 3.0, Color.WHITE)
