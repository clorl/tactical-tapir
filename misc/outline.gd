@tool
extends Node
class_name Outline

@export var targets: Array[GeometryInstance3D]
@export var material: ShaderMaterial
@export var enabled := false:
	set(v):
		enabled = v
		_set_enabled(v)
	get:
		if not targets.size(): return false
		for t in targets:
			if not is_instance_valid(t): continue
			return targets[0].material_overlay != null and targets[0].material_overlay == material
		return false

@export_group("Shader params")
@export var color := Color.ORANGE:
	set(v): color = v; _update_params()
@export var thickness := 2.0:
	set(v): thickness = v; _update_params()

var _is_init := false

func _tree_enter():
	if _is_init: return
	assert(material)
	material = material.duplicate()
	_is_init = true

func enable():
	for t in targets:
		if not t.material_overlay or t.material_overlay != material:
			t.material_overlay = material

func disable():
	for t in targets:
		if t.material_overlay and t.material_overlay == material:
			t.material_overlay = null

func _set_enabled(val: bool):
	if val:
		enable()
	else:
		disable()

func _update_params():
	if not material: return
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("weight", thickness)
