extends Node2D

signal planet_selected(planet: PlanetData)
signal belt_selected(belt: AsteroidBeltData)
signal comet_selected(comet: CometData)

var system: Dictionary = {}
var planets: Array[PlanetData] = []
var asteroid_belts: Array = []
var comets: Array = []
var simulation_manager: SimulationManager
@export var move_speed := 300.0
@export var zoom_speed := 0.1
@export var min_zoom := 0.4
@export var max_zoom := 3.0

@onready var camera: Camera2D = $Camera2D
var focused_planet: PlanetData = null

# global_id de la planète où se trouve le vaisseau joueur, -1 = en orbite.
var ship_planet_id: int = -1

# Angle courant de l'orbite du vaisseau (planète ou étoile).
var ship_orbit_angle: float = 0.0
@export var ship_orbit_speed := 2.2


func set_ship_planet_id(planet_id: int) -> void:
	if ship_planet_id == planet_id:
		return

	ship_planet_id = planet_id
	ship_orbit_angle = 0.0
	queue_redraw()


func set_system(new_system: Dictionary) -> void:
	system = new_system
	planets = system["planets"]
	asteroid_belts = system.get("asteroid_belts", [])
	comets = system.get("comets", [])

	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE
	focused_planet = null

	_initialize_planets()
	_initialize_asteroid_belts()
	_initialize_comets()

	queue_redraw()


func get_planet_position(planet: PlanetData) -> Vector2:
	var angle: float = planet.get_meta("angle", 0.0)
	return Vector2(cos(angle), sin(angle)) * planet.orbit_distance


func focus_planet(planet: PlanetData, target_zoom := 1.6) -> void:
	focused_planet = planet
	camera.position = get_planet_position(planet)
	var z: float = clampf(target_zoom, min_zoom, max_zoom)
	camera.zoom = Vector2(z, z)
	queue_redraw()


func _initialize_planets() -> void:
	for planet in planets:
		var rng := RandomNumberGenerator.new()
		rng.seed = planet.seed

		planet.set_meta(
			"angle",
			rng.randf_range(0.0, TAU)
		)

		planet.set_meta(
			"orbit_speed",
			80.0 / max(planet.orbit_distance, 50.0)
		)

		_initialize_moons(planet)


func _initialize_moons(planet: PlanetData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet.seed

	var moons: Array[Dictionary] = []

	for i in planet.moon_count:
		var moon_seed: int = rng.randi()

		var distance: float = 18.0 + planet.size * 8.0
		distance += float(i) * 12.0
		distance += rng.randf_range(-3.0, 3.0)

		var size: float = rng.randf_range(0.15, 0.35)
		var orbit_speed: float = rng.randf_range(1.0, 2.5)
		var angle: float = rng.randf_range(0.0, TAU)

		var moon: Dictionary = {
			"id": i,
			"seed": moon_seed,
			"distance": distance,
			"size": size,
			"angle": angle,
			"orbit_speed": orbit_speed
		}

		moons.append(moon)

	planet.set_meta("moons", moons)


func _initialize_asteroid_belts() -> void:
	for belt in asteroid_belts:
		var rng := RandomNumberGenerator.new()
		rng.seed = belt.seed

		belt.set_meta(
			"angle",
			rng.randf_range(0.0, TAU)
		)

		var rocks: Array[Dictionary] = []

		for i in belt.rock_count:
			rocks.append({
				"angle": rng.randf_range(0.0, TAU),
				"offset": rng.randf_range(
					-belt.width / 2.0,
					belt.width / 2.0
				),
				"size": rng.randf_range(1.0, 3.0)
			})

		belt.set_meta("rocks", rocks)


func _initialize_comets() -> void:
	for comet in comets:
		comet.set_meta("theta", comet.phase)


func focus_belt(belt: AsteroidBeltData) -> void:
	focused_planet = null

	var angle: float = belt.get_meta("angle", 0.0)

	camera.position = Vector2(
		cos(angle),
		sin(angle)
	) * belt.orbit_distance

	camera.zoom = Vector2(1.4, 1.4)
	queue_redraw()


func focus_comet(comet: CometData) -> void:
	focused_planet = null

	var theta: float = comet.get_meta("theta", comet.phase)

	camera.position = comet.get_position(theta)
	camera.zoom = Vector2(1.6, 1.6)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return

	# Déplacement de la caméra.
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		direction.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	if direction != Vector2.ZERO:
		camera.position += (
			direction.normalized()
			* move_speed
			/ camera.zoom.x
			* delta
		)

	# Animation des planètes et des lunes, uniquement
	# lorsque la simulation est en marche.
	var animated: bool = (
		simulation_manager == null
		or simulation_manager.simulation_running
	)

	if focused_planet != null:
		if (
			Input.is_key_pressed(KEY_Z)
			or Input.is_key_pressed(KEY_S)
			or Input.is_key_pressed(KEY_Q)
			or Input.is_key_pressed(KEY_D)
			or Input.is_key_pressed(KEY_A)
		):
			focused_planet = null
		else:
			camera.position = get_planet_position(focused_planet)

	if animated:
		for planet in planets:
			var angle: float = planet.get_meta("angle")
			var orbit_speed: float = planet.get_meta("orbit_speed")

			angle += orbit_speed * delta

			planet.set_meta(
				"angle",
				angle
			)

			var moons: Array[Dictionary] = (
				planet.get_meta("moons")
			)

			for moon in moons:
				var moon_angle: float = moon["angle"]
				var moon_orbit_speed: float = moon["orbit_speed"]

				moon_angle += (
					moon_orbit_speed
					* delta
				)

				moon["angle"] = moon_angle

	# L'orbite du vaisseau tourne en permanence, même si la
	# simulation est en pause : le vaisseau bouge dès qu'il est en orbite.
	ship_orbit_angle = fmod(
		ship_orbit_angle + ship_orbit_speed * delta,
		TAU
	)

	# Rotation des ceintures d'astéroïdes.
	for belt in asteroid_belts:
		var belt_angle: float = belt.get_meta("angle", 0.0)
		var belt_speed: float = (
			60.0 / maxf(belt.orbit_distance, 50.0)
		)

		belt.set_meta(
			"angle",
			fmod(belt_angle + belt_speed * delta, TAU)
		)

	# Avancée des comètes sur leur orbite elliptique.
	for comet in comets:
		var theta: float = comet.get_meta("theta", comet.phase)

		comet.set_meta(
			"theta",
			fmod(theta + comet.angular_speed * delta, TAU)
		)

	queue_redraw()


func _draw() -> void:
	# Étoile centrale
	draw_circle(
		Vector2.ZERO,
		25.0,
		Color(1.0, 0.8, 0.3)
	)

	# Ceintures d'astéroïdes, derrière les planètes.
	for belt in asteroid_belts:
		_draw_asteroid_belt(belt)

	for planet in planets:
		var orbit_distance: float = planet.orbit_distance
		var angle: float = planet.get_meta("angle")

		# Orbite de la planète
		draw_arc(
			Vector2.ZERO,
			orbit_distance,
			0.0,
			TAU,
			64,
			Color(0.3, 0.3, 0.3, 0.5),
			1.0
		)

		# Position de la planète
		var planet_position: Vector2 = get_planet_position(planet)

		# Planète
		draw_circle(
			planet_position,
			planet.size * 5.0,
			_get_planet_color(planet.type)
		)

		# Lunes
		var moons: Array[Dictionary] = planet.get_meta("moons")

		_draw_moons(
			planet_position,
			moons
		)

	# Comètes, devant les planètes.
	for comet in comets:
		_draw_comet(comet)

	_draw_player_ship()


func _draw_asteroid_belt(belt: AsteroidBeltData) -> void:
	var angle: float = belt.get_meta("angle", 0.0)

	# Anneau de fond.
	draw_arc(
		Vector2.ZERO,
		belt.orbit_distance,
		0.0,
		TAU,
		96,
		Color(0.6, 0.55, 0.5, 0.15),
		belt.width
	)

	var rocks: Array = belt.get_meta("rocks", [])

	for rock in rocks:
		var rock_angle: float = angle + rock["angle"]
		var radius: float = (
			belt.orbit_distance + rock["offset"]
		)

		var rock_position := Vector2(
			cos(rock_angle),
			sin(rock_angle)
		) * radius

		draw_circle(
			rock_position,
			rock["size"],
			Color(0.65, 0.6, 0.55, 0.9)
		)


func _draw_comet(comet: CometData) -> void:
	var theta: float = comet.get_meta("theta", comet.phase)
	var comet_position := comet.get_position(theta)

	# Trajectoire elliptique.
	var path := PackedVector2Array()

	for i in range(65):
		path.append(
			comet.get_position(TAU * float(i) / 64.0)
		)

	draw_polyline(
		path,
		Color(0.6, 0.8, 1.0, 0.25),
		1.0
	)

	if comet_position.length() < 1.0:
		return

	# Traînée, orientée à l'opposé de l'étoile.
	var away: Vector2 = comet_position.normalized()

	var distance: float = comet_position.length()

	var tail_length: float = comet.size * 6.0 * clamp(
		1.4 - distance / maxf(comet.semi_major * 2.0, 1.0),
		0.4,
		2.0
	)

	var perpendicular := Vector2(-away.y, away.x)

	var tail_base_left := (
		comet_position
		+ perpendicular * comet.size * 0.6
	)
	var tail_base_right := (
		comet_position
		- perpendicular * comet.size * 0.6
	)
	var tail_tip := comet_position + away * tail_length

	draw_colored_polygon(
		PackedVector2Array([
			tail_base_left,
			tail_base_right,
			tail_tip
		]),
		Color(0.7, 0.9, 1.0, 0.35)
	)

	draw_line(
		comet_position,
		tail_tip,
		Color(0.9, 0.97, 1.0, 0.6),
		1.5
	)

	# Corps de la comète.
	draw_circle(
		comet_position,
		comet.size,
		Color(0.85, 0.95, 1.0)
	)

	draw_circle(
		comet_position,
		comet.size + 3.0,
		Color(0.7, 0.9, 1.0, 0.35)
	)


func _draw_player_ship() -> void:
	var ship_position := Vector2(40.0, -30.0)
	var direction := Vector2(1.0, -0.4).normalized()
	var highlight: PlanetData = null

	if ship_planet_id >= 0:
		for planet in planets:
			if planet.global_id == ship_planet_id:
				highlight = planet
				break

	if highlight != null:
		var planet_position: Vector2 = get_planet_position(highlight)
		var radius: float = max(
			highlight.size * 5.0 + 16.0,
			22.0
		)

		# Position du vaisseau sur son orbite autour de la planète.
		var radial := Vector2(
			cos(ship_orbit_angle),
			sin(ship_orbit_angle)
		)

		ship_position = planet_position + radial * radius

		# Direction tangente à l'orbite.
		direction = Vector2(-radial.y, radial.x)

		# Trajectoire de l'orbite du vaisseau.
		draw_arc(
			planet_position,
			radius,
			0.0,
			TAU,
			48,
			Color(0.5, 0.8, 1.0, 0.35),
			1.0
		)

		# Halo autour de la planète abritant le vaisseau.
		draw_arc(
			planet_position,
			highlight.size * 5.0 + 5.0,
			0.0,
			TAU,
			32,
			Color(0.5, 0.8, 1.0, 0.9),
			1.5
		)

	else:
		# En orbite de l'étoile : le vaisseau tourne autour de celle-ci.
		var radius := 48.0
		var radial := Vector2(
			cos(ship_orbit_angle),
			sin(ship_orbit_angle)
		)

		ship_position = radial * radius
		direction = Vector2(-radial.y, radial.x)

		draw_arc(
			Vector2.ZERO,
			radius,
			0.0,
			TAU,
			48,
			Color(1.0, 0.8, 0.3, 0.3),
			1.0
		)

	ShipDrawing.draw_ship(
		self,
		ship_position,
		direction,
		0.6,
		6.0,
		12.0
	)


func _draw_moons(
	planet_position: Vector2,
	moons: Array[Dictionary]
) -> void:
	for moon in moons:
		var distance: float = moon["distance"]
		var angle: float = moon["angle"]
		var size: float = moon["size"]

		# Orbite de la lune
		draw_arc(
			planet_position,
			distance,
			0.0,
			TAU,
			32,
			Color(0.4, 0.4, 0.4, 0.35),
			1.0
		)

		# Position de la lune
		var moon_position: Vector2 = planet_position + Vector2(
			cos(angle) * distance,
			sin(angle) * distance
		)

		# Lune
		draw_circle(
			moon_position,
			size * 5.0,
			Color(0.75, 0.75, 0.75)
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseButton:
		if not event.pressed:
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.0 - zoom_speed)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 + zoom_speed)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			_select_planet_at_position(
				get_global_mouse_position()
			)

			get_viewport().set_input_as_handled()

func _select_planet_at_position(mouse_position: Vector2) -> void:
	var zoom: float = $Camera2D.zoom.x
	var selection_distance: float = 20.0 / zoom

	var closest_planet: PlanetData = null
	var closest_planet_distance: float = INF

	for planet in planets:
		var distance: float = mouse_position.distance_to(
			get_planet_position(planet)
		)

		if distance < closest_planet_distance:
			closest_planet_distance = distance
			closest_planet = planet

	var closest_comet: CometData = null
	var closest_comet_distance: float = INF

	for comet in comets:
		var theta: float = comet.get_meta("theta", comet.phase)

		var distance: float = mouse_position.distance_to(
			comet.get_position(theta)
		) - comet.size

		if distance < closest_comet_distance:
			closest_comet_distance = distance
			closest_comet = comet

	var closest_belt: AsteroidBeltData = null
	var closest_belt_distance: float = INF

	for belt in asteroid_belts:
		# Distance à l'anneau : bande entre deux rayons.
		var distance: float = absf(
			mouse_position.length() - belt.orbit_distance
		) - belt.width / 2.0

		distance = maxf(distance, 0.0)

		if distance < closest_belt_distance:
			closest_belt_distance = distance
			closest_belt = belt

	# La cible la plus proche l'emporte.
	if (
		closest_planet != null
		and closest_planet_distance <= selection_distance
		and closest_planet_distance <= closest_comet_distance
		and closest_planet_distance <= closest_belt_distance
	):
		planet_selected.emit(closest_planet)
		return

	if (
		closest_comet != null
		and closest_comet_distance <= selection_distance
		and closest_comet_distance <= closest_belt_distance
	):
		comet_selected.emit(closest_comet)
		return

	if closest_belt != null and closest_belt_distance <= selection_distance:
		belt_selected.emit(closest_belt)
		
func _zoom(factor: float) -> void:
	var new_zoom: float = (
		camera.zoom.x * factor
	)

	new_zoom = clamp(
		new_zoom,
		min_zoom,
		max_zoom
	)

	camera.zoom = Vector2(
		new_zoom,
		new_zoom
	)

	queue_redraw()
