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

func get_planet_description() -> String:
	if planet == null:
		return ""

	var info := planet.type.to_upper() + "\n\n"

	info += "Température : "
	info += str(snapped(planet.temperature, 0.1))
	info += " °C\n"

	info += "Gravité : "
	info += str(snapped(planet.gravity, 0.01))
	info += " g\n"

	info += "Eau : "
	info += str(snapped(planet.water, 0.1))
	info += " %\n"

	info += "Atmosphère : "
	info += str(snapped(planet.atmosphere, 0.1))
	info += " %\n"

	info += "Habitabilité : "
	info += str(snapped(planet.habitability, 0.1))
	info += " %\n\n"

	info += "Ressources\n"

	info += "Minéraux : "
	info += str(snapped(planet.minerals, 0.1))
	info += "\n"

	info += "Énergie : "
	info += str(snapped(planet.energy, 0.1))
	info += "\n"

	info += "Ressources biologiques : "
	info += str(snapped(planet.biological_resources, 0.1))
	info += "\n"

	info += "\nPopulation : "
	info += str(planet.population)

	info += "\nCapacité : "
	info += str(planet.population_capacity)

	if planet.has_life:
		info += "\n\nVie : "
		info += planet.life_stage

	if planet.civilization != null:
		info += "\nCivilisation : "
		info += planet.civilization.name

	return info
