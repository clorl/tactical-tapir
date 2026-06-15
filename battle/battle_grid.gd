@tool
extends Node3D
class_name BattleGrid

class CellInfo extends RefCounted:
	var neighbors := 6

	var neighbor_overrides = {}
	var vertices_overrides = {}

class Grid extends RefCounted:
	var size: Vector2
	var default_cell: CellInfo

	var grid_to_world: Transform2D
	var world_to_grid: Transform2D

	var cell_overrides: Dictionary[Vector2, CellInfo]

	func _init(n: int):
		default_cell = CellInfo.new()
		default_cell.neighbors = n

		var angle = (2.0*PI)/n
		var dist = cos(angle / 2.0) * 2.0
		grid_to_world.x = Vector2.RIGHT * dist
		grid_to_world.y = Vector2.RIGHT.rotated(angle).normalized() * dist
		world_to_grid = grid_to_world.affine_inverse()

	func _compute_overrides():
		var new_overrides = cell_overrides

		for pos in cell_overrides.keys():
			var cell = cell_overrides[pos]
			var neighbors = get_neighbors(pos, default_cell)
			var square_vertices = get_vertices(pos)
			var hex_vertices = [0, 1, 3, 4]
			for i in range(hex_vertices.size()):
				var square_vertex = square_vertices[i]
				var hex_vindex = hex_vertices[i]
				var override_map = get_vertex_index_for_neighbors(pos, hex_vindex, default_cell)
				for neigh_idx in override_map.keys():
					var neigh = neighbors[neigh_idx]
					var new_vertex = override_map[neigh_idx]
					var c = CellInfo.new()
					c.vertices_overrides = {}
					c.vertices_overrides.set(new_vertex, square_vertex)
					print(neigh)
					print(c.vertices_overrides)
					print(override_map)
					print(" ")
					new_overrides.set(neigh, c)
					
		cell_overrides = new_overrides
					

	func get_vertex_index_for_neighbors(pos: Vector2, vertex_idx: int, cell = null) -> Dictionary:
		cell = get_cell_info(pos, cell)
		vertex_idx = posmod(vertex_idx, cell.neighbors)
		var res = {}
		res[posmod(vertex_idx, cell.neighbors)] = posmod(vertex_idx + 4, cell.neighbors)
		res[posmod(vertex_idx - 1, cell.neighbors)] = posmod(vertex_idx + 2, cell.neighbors)
		return res

	func get_vertices(pos: Vector2, cell = null) -> PackedVector2Array:
		pos = grid_to_world * pos
		cell = get_cell_info(pos, cell)
		var v = []
		var angle = (2.0*PI)/cell.neighbors
		var start_angle = -angle/2.0
		var start_vector = Vector2.RIGHT.rotated(start_angle)
		for i in range(cell.neighbors):
			v.append(pos + start_vector.rotated(angle * i))
		
		for idx in cell.vertices_overrides.keys():
			v[idx] = cell.vertices_overrides[idx]
			
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
		var cell_info = CellInfo.new()
		cell_info.neighbors = c.neighbors
		grid.cell_overrides.set(pos_2d, cell_info)
		pos_2d = grid.grid_to_world * pos_2d
		modifiers.set(pos_2d, c)
	# var test = CellInfo.new()
	# test.vertices_overrides = {
	# 	2: Vector2(2, 2)
	# }
	#grid.cell_overrides.set(Vector2(0, 0), test)
	grid._compute_overrides()

func _process(_dt):
	DebugDraw3D.draw_aabb(grid_aabb, Color.YELLOW)
	DebugDraw3D.draw_arrow(Vector3.ZERO, xz(grid.grid_to_world.x), Color.RED, .1)
	DebugDraw3D.draw_arrow(Vector3.ZERO, xz(grid.grid_to_world.y), Color.GREEN, .1)
	for x in range(-grid_size.x, grid_size.x + 1):
		for y in range(-grid_size.y, grid_size.y + 1):
			draw_vertices_2d(grid.get_vertices(Vector2(x,y)), Color.WHITE, str(x, ";", y))
	for coord in modifiers.keys():
		var mod = modifiers[coord]
		DebugDraw3D.draw_sphere(mod.global_position, .01, Color.CYAN)
		DebugDraw3D.draw_line(mod.global_position, xz(coord), Color.CYAN)

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


		
