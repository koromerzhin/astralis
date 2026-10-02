extends Node2D


var planet: PlanetData


func set_planet(new_planet: PlanetData) -> void:
	planet = new_planet
	queue_redraw()


func _draw() -> void:
	if planet == null:
		return

	var radius: float = planet.size * 80.0

	draw_circle(
		Vector2.ZERO,
		radius,
		_get_planet_color(planet.type)
	)


func _get_planet_color(planet_type: String) -> Color:
	match planet_type:
		"rocky":
			return Color(0.55, 0.45, 0.35)

		"desert":
			return Color(0.85, 0.65, 0.3)

		"ocean":
			return Color(0.2, 0.5, 0.9)

		"ice":
			return Color(0.7, 0.85, 1.0)

		"gas_giant":
			return Color(0.8, 0.55, 0.35)

		_:
			return Color.WHITE
