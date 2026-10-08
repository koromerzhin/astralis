class_name ShipDrawing
extends RefCounted

# Apparence du vaisseau joueur : chasseur delta vu de dessus.
# Repère local : l'avant du vaisseau est sur +X, la rotation
# est déduite de la direction de déplacement.

const HULL_COLOR := Color(0.55, 0.66, 0.8)
const FUSELAGE_COLOR := Color(0.84, 0.91, 1.0)
const EDGE_COLOR := Color(0.6, 0.9, 1.0, 0.95)
const WING_EDGE_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const COCKPIT_COLOR := Color(0.12, 0.3, 0.5, 0.95)
const ENGINE_CORE_COLOR := Color(0.9, 0.98, 1.0, 0.9)
const TRAIL_COLOR := Color(0.4, 0.8, 1.0, 0.7)
const TRAIL_CORE_COLOR := Color(0.8, 0.95, 1.0, 0.5)
const HALO_COLOR := Color(0.5, 0.8, 1.0, 0.25)

# Silhouette complète : fuselage + ailes delta.
const OUTLINE := [
	Vector2(13.0, 0.0),
	Vector2(1.5, 3.0),
	Vector2(-6.5, 9.5),
	Vector2(-10.5, 9.5),
	Vector2(-8.5, 3.2),
	Vector2(-11.5, 2.0),
	Vector2(-11.5, -2.0),
	Vector2(-8.5, -3.2),
	Vector2(-10.5, -9.5),
	Vector2(-6.5, -9.5),
	Vector2(1.5, -3.0),
]

# Seulement le fuselage : couleur claire pour le relief.
const FUSELAGE := [
	Vector2(13.0, 0.0),
	Vector2(1.5, 3.0),
	Vector2(-8.5, 3.2),
	Vector2(-11.5, 2.0),
	Vector2(-11.5, -2.0),
	Vector2(-8.5, -3.2),
	Vector2(1.5, -3.0),
]

# Hublot en losarge, dans l'avant du fuselage.
const COCKPIT := [
	Vector2(7.5, 0.0),
	Vector2(4.0, 1.7),
	Vector2(1.5, 0.0),
	Vector2(4.0, -1.7),
]

# Nervures des ailes (bord avant et bord de fuite).
const WING_EDGES := [
	[Vector2(1.5, 3.0), Vector2(-6.5, 9.5)],
	[Vector2(-10.5, 9.5), Vector2(-8.5, 3.2)],
	[Vector2(1.5, -3.0), Vector2(-6.5, -9.5)],
	[Vector2(-10.5, -9.5), Vector2(-8.5, -3.2)],
]

const ENGINE_OFFSET := -11.5


static func draw_ship(
	canvas: CanvasItem,
	position: Vector2,
	direction: Vector2,
	ship_scale: float,
	trail_length: float = 0.0,
	halo_radius: float = 0.0
) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var dir: Vector2 = direction.normalized()
	var perpendicular := Vector2(-dir.y, dir.x)

	var engine_position: Vector2 = (
		position + dir * (ENGINE_OFFSET * ship_scale)
	)

	# Halo du vaisseau.
	if halo_radius > 0.0:
		canvas.draw_circle(
			position,
			halo_radius,
			HALO_COLOR
		)

	# Traînée de propulsion, derrière le vaisseau.
	if trail_length > 0.0:
		var trail_end: Vector2 = (
			engine_position - dir * trail_length
		)

		canvas.draw_line(
			engine_position,
			trail_end,
			TRAIL_COLOR,
			maxf(2.5 * ship_scale, 1.5)
		)

		canvas.draw_line(
			engine_position,
			trail_end,
			TRAIL_CORE_COLOR,
			maxf(1.0 * ship_scale, 1.0)
		)

	# Corps : ailes sombres, fuselage clair.
	canvas.draw_colored_polygon(
		_to_world(OUTLINE, position, dir, perpendicular, ship_scale),
		HULL_COLOR
	)

	canvas.draw_colored_polygon(
		_to_world(FUSELAGE, position, dir, perpendicular, ship_scale),
		FUSELAGE_COLOR
	)

	# Contour du vaisseau.
	canvas.draw_polyline(
		_close(_to_world(
			OUTLINE, position, dir, perpendicular, ship_scale
		)),
		EDGE_COLOR,
		maxf(1.4 * ship_scale, 1.0)
	)

	# Nervures des ailes.
	for edge in WING_EDGES:
		canvas.draw_line(
			_to_point(edge[0], position, dir, perpendicular, ship_scale),
			_to_point(edge[1], position, dir, perpendicular, ship_scale),
			WING_EDGE_COLOR,
			maxf(1.0 * ship_scale, 1.0)
		)

	# Hublot.
	canvas.draw_colored_polygon(
		_to_world(COCKPIT, position, dir, perpendicular, ship_scale),
		COCKPIT_COLOR
	)

	# Réacteur pulsé.
	var pulse: float = (
		0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	)

	canvas.draw_circle(
		engine_position,
		(3.0 + 2.0 * pulse) * ship_scale,
		Color(
			ENGINE_CORE_COLOR.r,
			ENGINE_CORE_COLOR.g,
			ENGINE_CORE_COLOR.b,
			0.12 + 0.18 * pulse
		)
	)

	canvas.draw_circle(
		engine_position,
		1.6 * ship_scale,
		ENGINE_CORE_COLOR
	)


static func _to_world(
	points: Array,
	position: Vector2,
	dir: Vector2,
	perpendicular: Vector2,
	ship_scale: float
) -> PackedVector2Array:
	var world := PackedVector2Array()
	world.resize(points.size())

	for i in points.size():
		world[i] = (
			position
			+ dir * (points[i].x * ship_scale)
			+ perpendicular * (points[i].y * ship_scale)
		)

	return world


static func _to_point(
	point: Vector2,
	position: Vector2,
	dir: Vector2,
	perpendicular: Vector2,
	ship_scale: float
) -> Vector2:
	return (
		position
		+ dir * (point.x * ship_scale)
		+ perpendicular * (point.y * ship_scale)
	)


static func _close(points: PackedVector2Array) -> PackedVector2Array:
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed
