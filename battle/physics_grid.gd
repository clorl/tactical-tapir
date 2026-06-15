@tool
extends Node2D

class CellInfo extends RefCounted:
	var north: int
	var south: int

class NodeData extends RefCounted:
	var velocity: Vector2

class Graph extends RefCounted:
	var size: Vector2
	var default_neighbors := 6
	var cells: Dictionary
	var nodes: Array
	var nodes_data: Array
	var edges: Array
	var transform: Transform2D

	var init = false
	var ideal_edge_length: float = -1
	const FAC = .0001
	var repulsion_strength = 1.0
	var attraction_strength = 1.0
	var gravity_strength = 1.0
	var damping = 0.9

	func _init(size: Vector2, neighbors: int):
		size = size

		var angle = (2.0 * PI)/default_neighbors
		var dist = cos(angle / 2.0) * 2.0
		transform.x = Vector2.RIGHT * dist
		transform.y = Vector2.RIGHT.rotated(-angle).normalized() * dist

	func init_sim():
		var a = nodes[edges[0][0]]
		var b = nodes[edges[0][1]]
		ideal_edge_length = a.distance_to(b)
		for i in range(nodes.size()):
			var d = NodeData.new()
			nodes_data.append(d)

	func simulation_step():
		print("Sim step")
		for i in range(nodes_data.size()):
			nodes_data[i].velocity *= damping

		#### REPULSION
		for i in range(nodes.size()):
			var node_a = nodes[i]
			if node_a.x == INF: continue
			for j in range(i+1, nodes.size()):
				var node_b = nodes[j]
				if node_b.x == INF: continue

				var dir = node_a - node_b
				var dist = dir.length()
				if dist < 0.1:
					dir = Vector2(randf() - 0.5, randf() - 0.5).normalized()
					dist = 1.0
				var force = dir.normalized() * (repulsion_strength / (dist * dist)) * FAC
				nodes_data[i].velocity += force
				nodes_data[j].velocity -= force
				
		#### ATTRACTION
		for edge in edges:
			var node_a = nodes[edge[0]]
			var node_b = nodes[edge[1]]
			if node_a.x == INF or node_b.x == INF: continue

			var dir = node_a - node_b
			var dist = dir.length()
			if dist < 0.1: continue

			var displacement = dist - ideal_edge_length
			var force = dir.normalized() * (attraction_strength * displacement)
			nodes_data[edge[0]].velocity += force * FAC
			nodes_data[edge[1]].velocity -= force * FAC

		### GRAVITY
		for i in range(nodes.size()):
			var node = nodes[i]
			if node.x == INF: continue
			var dir = -node
			var dist = dir.length()
			if dist < 0.1: continue
			var force = dir.normalized() * dist * gravity_strength
			nodes_data[i].velocity += force * FAC

		for i in range(nodes_data.size()):
			if nodes[i].x == INF: continue
			nodes[i] += nodes_data[i].velocity


	func generate():
		init = false
		nodes.clear()
		edges.clear()
		cells.clear()
		nodes_data.clear()

		var angle = (2.0 * PI)/default_neighbors
		var dist = cos(angle / 2.0) * 2.0

		for x in range(-size.x - 1, (size.x * 2)):
			for y in range(-size.y - 1, (size.y * 2)):
				var pos = Vector2(x, y)
				var cell = CellInfo.new()
				var north = transform * pos + Vector2.RIGHT.rotated(-1.5 * angle)
				var south = transform * pos + Vector2.RIGHT.rotated(1.5 * angle)
				nodes.append(north)
				cell.north = nodes.size() - 1
				nodes.append(south)
				cell.south = nodes.size() - 1
				cells.set(pos, cell)
		
		for pos in cells.keys():
			var info = cells[pos]
			var other = cells.get(pos + Vector2(0, 1))
			if other != null:
				add_unique_edge(info.north, other.south)
			other = cells.get(pos + Vector2(-1, 1))
			if other != null:
				add_unique_edge(info.north, other.south)
			other = cells.get(pos + Vector2(1, -2))
			if other != null:
				pass
				add_unique_edge(info.south, other.north)

		var cell = cells[Vector2(0,0)]
		node_remove(cell.north)
		node_remove(cell.south)
		cell.north = cells[Vector2(-1, 1)].south
		cell.south = cells[Vector2(1, -1)].north
		add_unique_edge(cell.north, cells[Vector2(0, 1)].south)
		add_unique_edge(cell.south, cells[Vector2(1, -1)].north)

	func node_remove(idx: int):
		for i in range(edges.size() - 1, 0, -1):
			var edge = edges[i]
			if edge[0] == idx or edge[1] == idx:
				edges.remove_at(i)
				i -= 1
		nodes[idx] = Vector2(INF, INF)

	func add_unique_edge(a: int, b: int) -> int:
		var idx = edges.find_custom(func(e):
			return e[0] == a and e[1] == b or e[1] == a and e[0] == b
		)
		if idx > -1: return idx
		edges.append([a, b])
		return edges.size() - 1

	func node_get_neighbors(node: int) -> Array:
		return edges.filter(func(e): return e[0] == node or e[1] == node)\
					.map(func(e):
						if e[0] == node:
							return e[1]
						else:
							return e[0]
						)

@export var size: Vector2
@export_tool_button("Step") var step_btn = step
@export_tool_button("Reset") var res_btn = reset_sim


@export var playing := false
@export var repulsion_strength = 1.0:
	set(v):
		repulsion_strength = v
		generate()
@export var attraction_strength = 1.0:
	set(v):
		attraction_strength = v
		generate()
@export var gravity_strength = 1.0:
	set(v):
		gravity_strength = v
		generate()
@export var damping = 0.9:
	set(v):
		damping = v
		generate()

var graph: Graph

func _ready():
	generate()

func generate():
	graph = Graph.new(size, 6)
	graph.size = size
	graph.repulsion_strength = repulsion_strength
	graph.attraction_strength = attraction_strength 
	graph.gravity_strength = gravity_strength
	graph.damping = damping
	graph.generate()
	graph.init_sim()

func step():
	graph.simulation_step()
	queue_redraw()

func reset_sim():
	graph.init = false
	generate()

func _process(_dt):
	if not playing: return
	step()
	queue_redraw()

func _draw():
	var t: Transform2D
	t = transform.scaled(Vector2(20, 20))

	var neighs = graph.node_get_neighbors(20)
	for pos in graph.cells.keys():
		var color = Color.CYAN
		if pos == Vector2(0, 1):
			color = Color.GREEN
		elif pos == Vector2(1, 0):
			color = Color.RED
		var info = graph.cells[pos]

		draw_circle(t * graph.nodes[info.north], 1.0, Color.MAGENTA if info.north in neighs else Color.WHITE)
		draw_circle(t * graph.nodes[info.south], 1.0, Color.MAGENTA if info.south in neighs else Color.WHITE)
		var center = t * (graph.nodes[info.north] + graph.nodes[info.south]) / 2.0
		# draw_line(t * info.north, center, color)
		# draw_line(t * info.south, center, color)
		draw_circle(center, .8, color)
	for e in graph.edges:
		var a = t * graph.nodes[e[0]]
		var b = t * graph.nodes[e[1]]
		draw_line(a, b, Color.WHITE)

func _notification(what):
	if what == NOTIFICATION_EDITOR_POST_SAVE:
		generate()
