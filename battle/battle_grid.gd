@tool
extends Node3D
class_name BattleGrid

const DBG_POINT_SIZE := 0.1

@export var base_neighbor_count := 6:
	set(v):
		base_neighbor_count = v
		generate()
var modifiers: Array[GraphModifier]
var mod_map := {}

var vertices: PackedVector2Array

var grid: Grid

@export_group("Debug")
@export var draw_vertices := true
@export var preview_cursor := -1

var once = false
var _ts = 0
var _generate_duration = 0
var _first_frame_duration = 0
func generate():
	once = false
	_ts = Time.get_ticks_msec()
	_generate_duration = 0
	_first_frame_duration = 0
	grid = Grid.new()
	grid.neighbor_count = base_neighbor_count
	modifiers.clear()
	vertices.clear()
	
	for c in get_children():
		if c is GraphModifier:
			modifiers.append(c)

	var cell = add_cell(Vector2(0,0))
	var neighbors = grid.get_default_neighbors(Vector2(0,0))
	for pos in neighbors:
		grid.add_cell(pos)
	vertices = grid.get_vertices()
	
	_generate_duration = Time.get_ticks_msec() - _ts
	_ts = Time.get_ticks_msec()

func add_cell(pos: Vector2) -> Cell:
	var mod = get_modifier(pos)
	if mod != null and is_instance_valid(mod):
		var c = Cell.new()
		c.neighbor_count = mod.neighbor_count
		return grid.add_cell(pos, c)
	return grid.add_cell(pos)

func get_modifier(for_pos: Vector2) -> Variant:
	if mod_map.has(for_pos):
		return mod_map.get(for_pos)

	var idx = modifiers.find_custom(func(mod):
		var va = transform * Vector3(for_pos.x, 0, for_pos.y)
		var vb = Vector3(mod.global_position.x, 0, mod.global_position.z)
		return va.distance_to(vb) < 1.0
	)
	if idx != -1 and is_instance_valid(modifiers[idx]):
		mod_map.set(for_pos, modifiers[idx])
		return modifiers[idx]

	mod_map.set(for_pos, null)
	return null

var timer = 0
func _process(_dt):
	if not Engine.is_editor_hint(): return
	if draw_vertices:
		var vs = grid.get_vertices()
		for i in range(vs.size()):
			if preview_cursor > -1 and i != preview_cursor: continue
			draw_point(vs[i], Color.GREEN, str(i), Color.WHITE)
		for pos in grid.cells.keys():
			draw_polygon(grid.get_vertices(pos), Color.GREEN)
			
		var mod = get_modifier(Vector2.ZERO)
		draw_point(Vector2(0,0), Color.RED if mod != null else Color.YELLOW, str(grid.get_vertices_idx(Vector2(0, 0))) )

	if not once:
		once = true
		_first_frame_duration = Time.get_ticks_msec() - _ts

		print("Generate time: %d ms, First frame time: %d ms, Total: %d ms" % [_generate_duration, _first_frame_duration, _generate_duration + _first_frame_duration])

func _ready():
	generate()

func _notification(what):
	if not Engine.is_editor_hint(): return
	if what == NOTIFICATION_EDITOR_POST_SAVE or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		generate()

func draw_point(pos: Vector2, color := Color.WHITE, text = "", text_color = color, text_size := 32):
	var world_pos = transform * Vector3(pos.x, 0, pos.y)
	DebugDraw3D.draw_sphere(world_pos, 0.02, color)
	if text != "":
		DebugDraw3D.draw_text(world_pos + Vector3.UP * 2.0, text, text_size, text_color)

func draw_polygon(vertices: PackedVector2Array, color := Color.WHITE, callable = null):
	for i in range(vertices.size()):
		var va = vertices[i]
		var vb = vertices[(i+1)%vertices.size()]
		var a = Vector3(va.x, 0, va.y)
		var b = Vector3(vb.x, 0, vb.y)
		if callable == null or not callable is Callable:
			DebugDraw3D.draw_line(a, b, color)
		else:
			callable.call(a, b, color)

class Grid extends RefCounted:
	var base_cell: Cell
	var cells: Dictionary[Vector2, Cell]

	var neighbor_count: int:
		set(v):
			neighbor_count = v
			base_cell = Cell.new()
			base_cell.neighbor_count = v
			_should_recompute_vertices = true

	func get_cell(pos: Vector2) -> Cell:
		var c = cells.get(pos)
		if c != null:
			return c
		if base_cell == null:
			base_cell = Cell.new(neighbor_count)
		return base_cell

	func get_default_neighbors(pos: Vector2) -> PackedVector2Array:
		var arr = PackedVector2Array([])
		var c = base_cell #get_cell(pos)
		if c == null: return arr
		for n in c.get_neighbors():
			arr.append(n + pos)
		return arr

	func get_neighbors(pos: Vector2) -> PackedVector2Array:
		var arr = PackedVector2Array([])
		var c = get_cell(pos)
		if c == null: return arr
		for n in c.get_neighbors():
			arr.append(n + pos)
		return arr

	func get_vertices(id = null) -> PackedVector2Array:
		_compute_vertices()
		var vertices = []
		if id != null and id is Vector2:
			var c = cells.get(id)
			if c == null: c = base_cell
			for v in c.get_vertices():
				vertices.append(v + id)
			return vertices

		return _vertices

	var _vertices: PackedVector2Array
	var _merged_vertices: Dictionary[Vector2, int]
	var _should_recompute_vertices := true
	func _compute_vertices():
		if not _should_recompute_vertices: return
		_vertices.clear()
		_merged_vertices.clear()

		var vertices: Array = []
		var needs_adjusting_vertices: Array = []
		for pos in cells.keys():
			var cell = cells[pos]
			for v in cell.get_vertices():
				var found = vertices.find_custom(func(it):
					return it.distance_squared_to(pos + v) < 0.01
				)
				if found > -1:
					_merged_vertices.set(v, found)
				else:
					vertices.append(pos + v)

		for pos in cells.keys():
			var c = cells[pos]
			if c == base_cell: continue
			#var adjacent_vertices = get_

		_vertices = PackedVector2Array(vertices)
		_should_recompute_vertices = false

	func get_vertices_idx(pos: Vector2) -> Array:
		_compute_vertices()
		var indices = []
		var c = get_cell(pos)
		if c == null: c = base_cell
		for v in c.get_vertices():
			var remapped = _merged_vertices.get(pos + v)
			if remapped != null:
				indices.append(remapped)
			else:
				indices.append(_vertices.find(pos+v))

		return indices

	func get_vertices_in_range(pos: Vector2, distance: float) -> PackedVector2Array:
		_compute_vertices()
		return Array(_vertices).filter(func(v):
			return v.distance_to(pos) <= distance
		)

	func add_cell(v: Vector2, cell_override = null) -> Cell:
		if cells.has(v):
			return cells.get(v)
			
		_should_recompute_vertices = true
		if cell_override == null or not cell_override is Cell:
			if base_cell == null:
				base_cell = Cell.new(neighbor_count)
			cells.set(v, base_cell)
			return base_cell

		cells.set(v, cell_override)
		return cell_override

	func clear():
		_should_recompute_vertices = true
		cells.clear()

class Cell extends RefCounted:
	var neighbor_count := 6

	func _init(neighbor_count := 6):
		neighbor_count = neighbor_count

	func get_vertices() -> PackedVector2Array:
		var verts = []
		var angle = (PI * 2.0) / neighbor_count
		var base_direction_vector = Vector2.UP
		if neighbor_count == 4:
			base_direction_vector = Vector2(1,1).normalized()
		for i in range(neighbor_count):
			verts.append(base_direction_vector.rotated(angle * i))
		return verts

	func get_neighbors() -> PackedVector2Array:
		var verts = []
		var angle = (PI * 2.0) / neighbor_count
		var base_direction_vector = Vector2.UP
		var neighbor_dist = cos(angle / 2.0) * 2.0
		if neighbor_count == 4:
			base_direction_vector = Vector2(1,1).normalized()
		base_direction_vector = base_direction_vector.rotated(angle / 2.0).normalized() * neighbor_dist
		for i in range(neighbor_count):
			verts.append(base_direction_vector.rotated(angle * i))
		return verts
