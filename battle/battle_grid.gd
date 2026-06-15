@tool
extends Node3D
class_name BattleGrid

class CellInfo extends RefCounted:
	var transform: Transform2D

	var neighbors := 6

	func get_vertices() -> PackedVector2Array:
		var v = []
		var angle = (2.0*PI)/neighbors
		var start_angle = -(angle /2.0)
		for i in range(neighbors):
			v.append(transform * Vector2.RIGHT.rotated(start_angle + angle * i))
		return v

class Grid extends RefCounted:
	var size: Vector2
	var default_cell: CellInfo

	var grid_to_world: Transform2D
	var world_to_grid: Transform2D

	var cell_overrides: Dictionary[Vector2, CellInfo]

	var intersections: Dictionary[Vector3, Vector2]

	func _init(n: int):
		default_cell = CellInfo.new()
		default_cell.neighbors = n

		var angle = (2.0*PI)/n
		var dist = cos(angle / 2.0) * 2.0
		grid_to_world.x = Vector2.RIGHT * dist
		grid_to_world.y = Vector2.RIGHT.rotated(angle).normalized() * dist
		world_to_grid = grid_to_world.affine_inverse()
		
	func _compute_overrides():
		intersections.clear()
		for pos in cell_overrides.keys():
			var cell = cell_overrides[pos]
			var wpos = grid_to_world * pos
			var vertices = cell.get_vertices()
			var orig_intersections = [
				{ "coord": Vector2(1, -1), "north": true},
				{ "coord": Vector2(0, 1), "north": false},
				{ "coord": Vector2(0, 0), "north": true},
				{ "coord": Vector2(-1, 1), "north": false},
				{ "coord": Vector2(0, -1), "north": true},
				{ "coord": Vector2(0, 0), "north": false},
			]

			for inter in orig_intersections:
				var inter_pos = get_intersection(inter.coord, inter.north)
				var sorted = range(vertices.size())
				sorted.sort_custom(func(a, b):
					return vertices[a].distance_to(inter_pos) < vertices[b].distance_to(inter_pos)
				)
				set_intersection(wpos + vertices[sorted[0]], pos + inter.coord, inter.north)

			# match cell.neighbors:
			# 	3:
			# 		set_intersection(wpos + vertices[0],pos + Vector2(1, -1), true)
			# 		set_intersection(wpos + vertices[1],pos + Vector2(0, 1), false)
			# 		set_intersection(wpos + vertices[2],pos + Vector2(-1, 1), false)
			# 		set_intersection(wpos + vertices[2],pos + Vector2(0, -1), true)
			# 		set_intersection(wpos + vertices[0], pos, false)
			# 		set_intersection(wpos + vertices[1], pos, true)
			# 	4: 
			# 		set_intersection(wpos + vertices[0], pos + Vector2(1, -1), true)
			# 		set_intersection(wpos + vertices[1], pos + Vector2(0, 1), false)
			# 		set_intersection(wpos + vertices[2], pos + Vector2(-1, 1), false)
			# 		set_intersection(wpos + vertices[3], pos + Vector2(0, -1), true)
			# 		set_intersection(wpos + vertices[1], pos, true)
			# 		set_intersection(wpos + vertices[3], pos, false)
			# 	5:
			# 		set_intersection(wpos + vertices[0], pos + Vector2(1, -1), true)
			# 		set_intersection(wpos + vertices[1], pos + Vector2(0, 1), false)
			# 		set_intersection(wpos + vertices[2], pos, true)
			# 		set_intersection(wpos + vertices[3], pos + Vector2(-1, 1), false)
			# 		set_intersection(wpos + vertices[3], pos + Vector2(0, -1), true)
			# 		set_intersection(wpos + vertices[4], pos, false)

	func get_intersection(cell_pos: Vector2, north := false, cell = null) -> Vector2:
		var existing = intersections.get(Vector3(cell_pos.x, cell_pos.y, 1 if north else 0))
		if existing != null:
			return existing
		cell = default_cell #get_cell_info(cell_pos, cell)
		var angle = (2.0*PI)/cell.neighbors
		return grid_to_world * cell_pos + Vector2.RIGHT.rotated((1.5 if north else -1.5) * angle)

	func set_intersection(new_pos: Vector2, cell_pos: Vector2, north := false):
		intersections.set(Vector3(cell_pos.x, cell_pos.y, 1 if north else 0), new_pos)

	func get_vertices(pos: Vector2, cell = null) -> PackedVector2Array:
		#pos = grid_to_world * pos
		#cell = get_cell_info(pos, cell)
		var v = []
		v.append(get_intersection(pos + Vector2(1, -1), true))
		v.append(get_intersection(pos + Vector2(0, 1), false))
		v.append(get_intersection(pos, true))
		v.append(get_intersection(pos + Vector2(-1, 1), false))
		v.append(get_intersection(pos + Vector2(0, -1), true))
		v.append(get_intersection(pos, false))
		#v.append(get_intersection(pos, true))
		return v

	func get_neighbors(pos: Vector2, cell = null) -> PackedVector2Array:
		cell = get_cell_info(pos, cell)
		assert(cell.neighbors == 4 or cell.neighbors == 6, "Only works for squares and hexes now")
		if cell.neighbors == 4:
			return [
				pos + Vector2(1, 0),
				pos + Vector2(0, 1),
				pos + Vector2(-1, 0),
				pos + Vector2(0, -1)
			]
		else:
			return [
				pos + Vector2(1, 0),
				pos + Vector2(0, 1),
				pos + Vector2(-1, 1),
				pos + Vector2(-1, 0),
				pos + Vector2(0, -1),
				pos + Vector2(1, -1)
			]

	func get_cell_info(pos: Vector2, fallback = null) -> CellInfo:
		if fallback != null and fallback is CellInfo:
			return fallback
		var c = cell_overrides.get(pos)
		return c if c != null else default_cell

@export_tool_button("Generate") var _generate_btn = generate

@export var default_neighbor_count := 6:
	set(v): default_neighbor_count = v; generate()
@export var grid_size := Vector2i(6,6):
	set(v): grid_size = v; generate()

var grid_aabb: AABB
var grid: Grid

var modifiers: Dictionary[Vector2, GraphModifier]

#### MAIN LOGIC

func generate():
	modifiers.clear()

	grid = Grid.new(default_neighbor_count)
	grid.size = Vector2(grid_size) * 2
	grid_aabb = AABB(Vector3(-grid_size.x, 0, -grid_size.y), Vector3(grid_size.x * 2, .1, grid_size.y * 2))

	for c in get_children():
		if not c is GraphModifier: continue
		var pos_2d = grid.world_to_grid * Vector2(c.position.x, -c.position.z)
		pos_2d.x = round(pos_2d.x)
		pos_2d.y = round(pos_2d.y)
		modifiers.set(pos_2d, c)
		var cell = CellInfo.new()
		cell.neighbors = c.neighbors
		if c.apply_rotation:
			cell.transform = cell.transform.rotated(c.rotation.y)
		if c.apply_scale:
			cell.transform = cell.transform.scaled(Vector2(c.scale.x, c.scale.z))
		if c.apply_position:
			var wpos = grid.grid_to_world * pos_2d
			var offset = Vector2(c.position.x, -c.position.z) - Vector2(wpos.x, wpos.y)
			cell.transform = cell.transform.translated(offset)

		grid.cell_overrides.set(pos_2d, cell)
		grid._compute_overrides()

func _process(_dt):
	generate()
	#DebugDraw3D.draw_aabb(grid_aabb, Color.YELLOW)
	#DebugDraw3D.draw_arrow(Vector3.ZERO, xz(grid.grid_to_world.x), Color.RED, .1)
	#DebugDraw3D.draw_arrow(Vector3.ZERO, xz(grid.grid_to_world.y), Color.GREEN, .1)
	for x in range(-grid_size.x, grid_size.x + 1):
		for y in range(-grid_size.y, grid_size.y + 1):
			draw_vertices_2d(grid.get_vertices(Vector2(x,y)), Color.WHITE)
	for coord in modifiers.keys():
		var mod = modifiers[coord]
		DebugDraw3D.draw_sphere(mod.global_position, .01, Color.CYAN)
		DebugDraw3D.draw_line(mod.global_position, xz(grid.grid_to_world * coord), Color.CYAN)

#### HELPERS

func draw_vertices_2d(vs: PackedVector2Array, color := Color.WHITE, text := ""):
	var center = Vector3.ZERO
	for i in range(vs.size()):
		var a = xz(vs[i])
		center += a
		var b = xz(vs[(i+1)%vs.size()])
		DebugDraw3D.draw_line(a, b, color)
	if text != "":
		center /= vs.size()
		DebugDraw3D.draw_text(center + Vector3.UP, text, 32, color)

func xz(v: Vector2) -> Vector3:
	return transform * Vector3(v.x, 0, -v.y)

func draw_point(pos: Vector2, color:= Color.WHITE, text := "", text_color := color, text_size := 32):
	var wpos = transform * Vector3(pos.x, 0, pos.y)
	DebugDraw3D.draw_sphere(wpos, .04, color)
	if text != "":
		DebugDraw3D.draw_text(wpos + Vector3.UP, text, text_size, text_color)

####

func _ready():
	generate()

func _notification(what):
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		generate()


		
