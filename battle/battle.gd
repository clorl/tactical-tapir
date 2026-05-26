@tool
extends Node3D


var graph_nodes : Dictionary[Vector2i, Vector3]
var graph_edges : Array[GraphEdge]
var graph_vertices := []

@export var graph_scale := 10.0
@export var graph_bounds := Rect2i(-5, -5, 5, 5)

@onready var square_node = $Square
var square:
	get(): return square_node.global_position
var square_point := Vector2i()

@export var special_cell := Vector2i()

@export_category("Debug Draw")
@export var draw_centers := true
@export var draw_edges := true
@export var draw_grid := false

func _ready():
	generate_graph()

func generate_graph():
	graph_nodes.clear()
	graph_edges.clear()
	graph_vertices.clear()

	#graph_nodes.set(Vector2i(0,0), Vector3(0.5*graph_scale,0,0))

	var dist := INF
	for x in range(graph_bounds.position.x, graph_bounds.end.x):
		for y in range(graph_bounds.position.y, graph_bounds.end.y):
			var coord = Vector2i(x,y)
			if graph_nodes.get(coord) != null: continue
			var world_pos := Vector3(x* graph_scale,0,y*graph_scale)

			if y % 2 == 0:
				world_pos.x = (x+0.5) * graph_scale
			graph_nodes.set(coord, world_pos)

			# TMP
			# var d = world_pos.distance_squared_to(square)
			# if d < dist:
			# 	dist = d
			# 	square_point = coord
			#/TMP

			var hex_neighbors = [
				Vector2i(-1, 0), Vector2i(1, 0),
			]
			if y % 2 == 0:
				hex_neighbors += [
				Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1,1),
				Vector2i(1,-1)
				]

			if coord == special_cell:
				hex_neighbors = [
					Vector2i(1, -1), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, -1)
				]
				
			for vec in hex_neighbors:
				if coord + vec == special_cell: continue
				var edge = GraphEdge.new(coord, coord + vec)
				if not graph_edges.any(edge.equals):
					graph_edges.append(edge)
					
	for coord in graph_nodes.keys():
		var r = graph_bounds.grow(-1)
		if not r.has_point(coord): continue
		var world_pos = graph_nodes.get(coord)
		if world_pos == null: continue
		var neighbors = get_neighbors(coord, true)
		var bounds = []
		for i in range(neighbors.size()):
			var a = graph_nodes.get(neighbors[i])
			var b = graph_nodes.get(neighbors[(i+1)%neighbors.size()])
			if a == null or b == null: continue
			var centroid = (world_pos + a + b) / 3.0
			bounds.append(centroid)
		for i in range(bounds.size()):
			var a = bounds[i]
			var b = bounds[(i+1)%bounds.size()]
			if graph_vertices.has([a,b]) or graph_vertices.has([b,a]): continue
			graph_vertices.append([a,b])

func _process(_dt):
	generate_graph()

	for i in range(graph_vertices.size()):
		if not draw_grid: break
		var a = graph_vertices[i][0]
		var b = graph_vertices[i][1]
		DebugDraw3D.draw_sphere(a, .01, Color.RED)
		#DebugDraw3D.draw_text(a + Vector3.UP, str(i))
		DebugDraw3D.draw_line(a,b)
	# for v in graph_vertices:
	# 	DebugDraw3D.draw_sphere(v, .01, Color.RED)
	# 	DebugDraw3D.draw_text(v + Vector3.UP, str(i))
	# 	i += 1

	for coord in graph_nodes.keys():
		if not draw_centers: break
		var node = graph_nodes.get(coord)
		DebugDraw3D.draw_sphere(node, .1, Color.GREEN if coord == special_cell else Color.WHITE)
		DebugDraw3D.draw_text(Vector3.UP + node, str(coord), 32, Color.GREEN if coord.y % 2 == 0 else Color.RED)
	for edge in graph_edges:
		if not draw_edges: break
		#if edge.a != Vector2i.ZERO and edge.b != Vector2i.ZERO: continue
		var a = graph_nodes.get(edge.a)
		var b = graph_nodes.get(edge.b)
		if not a or not b: continue
		DebugDraw3D.draw_line(a, b, Color.WHITE)
		# DebugDraw3D.draw_text((a + (b-a)/2.0) + Vector3.UP, str(edge))

func get_vertices(coord: Vector2i) -> PackedVector3Array:
	var pos = graph_nodes.get(coord)
	if pos == null: return []
	var pos_2d = Vector2(pos.x, pos.z)

	var midpoints = []
	for n in get_neighbors(coord):
		var neighbor = graph_nodes.get(n)
		if pos != null:
			var mp = (pos + neighbor)/2.0
			midpoints.append(mp)
			#print("Point: ", n, " Midpoint: ", mp, " Angle: ", angle)

	midpoints.sort_custom(func(a, b):
		var angle_a = pos_2d.angle_to_point(Vector2(a.x, a.z))
		var angle_b = pos_2d.angle_to_point(Vector2(b.x, b.z))
		return angle_a > angle_b
	)

	var res = []
	for i in range(midpoints.size()):
		var new_mp = (midpoints[i] + midpoints[(i+1)%midpoints.size()]) / 2.0
		res.append(new_mp)

	return res

# func get_vertices(coord: Vector2i, box_size := 2000.0) -> PackedVector3Array:
# 	var pos = graph_nodes.get(coord)
# 	if pos == null: return []

# 	var center := Vector2(pos.x, pos.z)
# 	var half = box_size/2.0
# 	var cell_polygon = PackedVector2Array([
# 		center + Vector2(-half, -half),
# 		center + Vector2(half, -half),
# 		center + Vector2(half, half),
# 		center + Vector2(-half, half),
# 	])

# 	for neighbor_coord in get_neighbors(coord):
# 		var neigh_pos_3d = graph_nodes.get(neighbor_coord)
# 		if neigh_pos_3d == null: continue
# 		var neighbor = Vector2(neigh_pos_3d.x, neigh_pos_3d.z)
# 		if center.is_equal_approx(neighbor): continue

# 		var midpoint = (center + neighbor) / 2.0
# 		var to_neighbor = (neighbor - center).normalized()
# 		var tangent = Vector2(-to_neighbor.y, to_neighbor.x)
# 		var clip_distance = box_size * 2.0
# 		var cutter = PackedVector2Array([
# 			midpoint,
# 			midpoint + to_neighbor * clip_distance,
# 			midpoint + to_neighbor * clip_distance + tangent * clip_distance,
# 			midpoint + to_neighbor * clip_distance - tangent * clip_distance,
# 		])

# 		var clipped_results = Geometry2D.clip_polygons(cell_polygon, cutter)
# 		if clipped_results.size() > 0:
# 			cell_polygon = clipped_results[0]
# 		else:
# 			print("Error")
# 			return []
# 	var vertices = PackedVector3Array()
# 	for vert in cell_polygon:
# 		vertices.append(Vector3(vert.x, center.y, vert.y))
# 	return vertices

func get_neighbors(coord: Vector2i, sorted := false) -> PackedVector2Array:
	var res = []
	for edge in graph_edges:
		if edge.a == coord:
			if not res.has(edge.b): res.append(edge.b)
		elif edge.b == coord:
			if not res.has(edge.a): res.append(edge.a)

	if sorted:
		var world_pos = graph_nodes.get(coord)
		if world_pos != null:
			var pos = Vector2(world_pos.x, world_pos.z)
			res.sort_custom(func(a, b):
				var world_a = graph_nodes.get(a)
				var world_b = graph_nodes.get(b)
				if world_a == null: return true
				if world_b == null: return false

				var angle_a = pos.angle_to_point(Vector2(world_a.x, world_a.z))
				var angle_b = pos.angle_to_point(Vector2(world_b.x, world_b.z))
				return angle_a > angle_b
			)
		
	return res

class GraphEdge extends RefCounted:
	var a: Vector2i
	var b: Vector2i

	func _init(vec_a: Vector2i, vec_b: Vector2i):
		self.a = vec_a
		self.b = vec_b

	func equals(other: GraphEdge):
		return (a == other.a and b == other.b) or (b == other.a and a == other.b)

	func _to_string() -> String:
		return "%d,%d\n%d,%d" % [a.x, a.y, b.x, b.y]
