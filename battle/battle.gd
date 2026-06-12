@tool
extends Node3D
@export var graph_bounds := Rect2i(-5, -5, 5, 5)
@export var cursor = 0

@export var enable_mod = false

var coords := {}
var graph := Graph.new()
var dual_graph := Graph.new()

var graph_modifiers: Array[GraphModifier]

func _notification(what):
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		generate_graph()

func _ready():
	generate_graph()

func generate_graph():
	graph_modifiers.clear()
	for c in get_children():
		if c is GraphModifier:
			graph_modifiers.append(c)
	graph = Graph.new()
	dual_graph = Graph.new()
	coords.clear()

	for x in range(graph_bounds.position.x, graph_bounds.end.x + 1):
		for y in range(graph_bounds.position.y, graph_bounds.end.y + 1):
			var v = Vector2(x, y)
			if not graph.add_unique_vertex(v + (Vector2(0.5, 0) if y % 2 != 0 else Vector2.ZERO)): continue
			var idx = graph.vertices.size() - 1
			coords.set(v, idx)

	for coord in coords.keys():
		var idx = coords.get(coord)
		var hex_neighbors = [
				Vector2(1, 0),
				Vector2(0, 1)
			]
		if int(coord.y) % 2 != 0:
			hex_neighbors += [
				Vector2(0, 1), Vector2(0, -1),
				Vector2(1,1),
				Vector2(1,-1),
			]

		if coord == Vector2(0,0) and enable_mod:
			hex_neighbors = [
				Vector2(-1,1),
				Vector2(1,0),
				Vector2(0,-1),
				Vector2(-1,0),
				]

		for vec in hex_neighbors:
			if coord + vec == Vector2(0,0) and enable_mod: continue
			var neighbor_idx = coords.get(coord + vec)
			if neighbor_idx == null: continue
			graph.add_unique_edge(idx, neighbor_idx)
		#var neighbors = graph.get_neighbors(idx, true)

		#var dual_face := []
		#if coord != Vector2(0, 0): continue
		# for i in range(neighbors.size()):
		# 	var a = neighbors[i]
		# 	var b = neighbors[(i+1)%neighbors.size()]
		# 	var f = [idx, a, b]
		# 	graph.add_unique_face(f)
		# 	var c = graph.face_centroid(f)
		# 	var centroid = Vector3(c.x, 0, c.y) * transform
		# 	dual_face.append(dual_graph.add_unique_vertex(centroid))
		# dual_graph.add_unique_face(dual_face)
	graph.faces.clear()
	graph.faces = graph.compute_faces()

func _process(_dt):
	var world_graph = graph.to_world(transform)
	var d = graph.get_dual().to_world(transform)
	var r = Rect2i(graph_bounds)
	r = r.grow(-2)

	var bds = graph_bounds.grow(-2)
	var rw = AABB()
	rw.position = Vector3(bds.position.x, -1, bds.position.y) * transform
	rw.end = Vector3(bds.end.x, 1, bds.end.y) * transform
	#DebugDraw3D.draw_aabb(rw, Color.YELLOW)

	for f in d.faces:
		for i in range(f.size()):
			var a = d.vertices[f[i]]
			var b = d.vertices[f[(i+1)%f.size()]]
			if not rw.has_point(a) or not rw.has_point(b): continue
			DebugDraw3D.draw_line(a, b, Color.GREEN)
			
	return

	for i in range(world_graph.vertices.size()):
		var coord = graph.vertices[i]
		if not r.has_point(coord): continue
		var v = world_graph.vertices[i]
		DebugDraw3D.draw_sphere(v, .1, Color.WHITE)
		DebugDraw3D.draw_text(v + Vector3.UP, str(i))

	# for edge in world_graph.edges:
	# 	break
	# 	var a = world_graph.vertices[edge[0]]
	# 	var b = world_graph.vertices[edge[1]]
	# 	DebugDraw3D.draw_line(a, b, Color.WHITE)
	for face in world_graph.faces:
		DebugDraw3D.draw_sphere(world_graph.face_centroid(face), .02, Color.CYAN)
		for i in range(face.size()):
			var a = world_graph.vertices[face[i]]
			var b = world_graph.vertices[face[(i+1)%face.size()]]
			DebugDraw3D.draw_line(a, b, Color.WHITE)

class Graph extends RefCounted:
	var vertices := []
	var edges := []
	var faces := []

	func add_unique_vertex(v: Variant) -> int:
		var idx = vertices.find(v)
		if idx <= -1:
			vertices.append(v)
			return vertices.size() - 1
		return idx

	func add_dissimilar_vertex(v: Variant, dist := .5) -> int:
		var idx = vertices.find_custom(func(i):
			return v.distance_to(i) <= dist
		)
		if idx <= -1:
			vertices.append(v)
			return vertices.size() - 1
		return idx

	func add_unique_edge(a: int, b: int) -> int:
		if a == b: return false
		var idx = edges.find_custom(func(edge):
			return (edge[0] == a and edge[1] == b) or (edge[1] == a and edge[0] == b)
			)
		if idx <= -1:
			edges.append([a, b])
			return edges.size() - 1
		return idx

	func get_neighbors(idx: int, sorted := false) -> Array:
		var neighbors = []
		for edge in edges:
			if edge[0] == idx:
				neighbors.append(edge[1])
			elif edge[1] == idx:
				neighbors.append(edge[0])

		if sorted:
			var pos = vertices[idx]
			neighbors.sort_custom(func(a, b):
				var va = vertices[a]
				var vb = vertices[b]
				var angle_a = pos.angle_to_point(va)
				var angle_b = pos.angle_to_point(vb)
				return angle_a > angle_b
			)
		return neighbors

	func add_unique_face(face: Array) -> int:
		var idx = faces.find_custom(func(f):
			return face_equals(f, face)
		)
		if idx <= -1:
			faces.append(face)
			return faces.size() - 1
		return idx
	

	func face_equals(a: Array, b: Array) -> bool:
		if a.size() != b.size(): return false
		for v in a:
			if not v in b: return false
		return true
			

	func face_centroid(face: Array):
		var sum = vertices.get(face[0]) * 0.0
		var count = 0
		for idx in face:
			var pos = vertices.get(idx)
			if pos == null: continue
			sum += pos
			count += 1
		return sum / count

	func vertex_get_faces(v: int) -> Array:
		return faces.filter(func(f):
			return v in f
		)

	func get_dual() -> Graph:
		var dual = Graph.new()

		for i in range(vertices.size()):
			var v = vertices[i]
			var centroids = vertex_get_faces(i).map(func (f): return face_centroid(f))
			centroids.sort_custom(func(a, b):
				var angle_a = vertices[i].angle_to_point(a)
				var angle_b = vertices[i].angle_to_point(b)
				return angle_a > angle_b
			)
			var face = []
			for c in centroids:
				var idx = dual.add_unique_vertex(c)
				face.append(idx)
			dual.add_unique_face(face)

		return dual

	func compute_faces() -> Array:
		var res = []
		var visited_edges := []
		var sorted_neighbors := []
		for i in range(vertices.size()):
			sorted_neighbors.append(get_neighbors(i, true))

		for start_node in range(vertices.size()):
			var neighbors = sorted_neighbors[start_node]
			for next_node in neighbors:
				var edge = [start_node, next_node]
				if visited_edges.has(edge): continue
				var face = []
				var current = start_node
				var succ = next_node
				while not visited_edges.has([current, succ]):
					visited_edges.append([current, succ])
					face.append(current)

					var succ_neighbors = sorted_neighbors[succ]
					var incoming_idx = succ_neighbors.find(current)
					var next_idx = (incoming_idx + 1)%succ_neighbors.size()

					current = succ
					succ = succ_neighbors[next_idx]
				if face.size() >= 3:
					res.append(face)
		return res

	func to_world(transform := Transform3D()) -> Graph:
		var graph = Graph.new()
		for v in vertices:
			graph.vertices.append(Vector3(v.x, 0, v.y) * transform)
		graph.edges = self.edges.duplicate()
		graph.faces = self.faces.duplicate()
		return graph

	func draw():
		pass
