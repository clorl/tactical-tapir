extends Area3D
class_name Interactable

signal hover_state_changed(new: bool)

@export var target: Node

var hovered := false:
	set(v):
		hovered = v
		hover_state_changed.emit(hovered)
		if target is Entity3D:
			Game.entity_hover_changed.emit(target, hovered)

func _ready():
	if not is_instance_valid(target):
		target = get_parent()
	assert(target)
	mouse_entered.connect(_mouse_enter)
	mouse_exited.connect(_mouse_exit)
	input_event.connect(_input_event)

func _input_event(cam, ev, pos, norm, idx):
	if target is Entity3D:
		Game.entity_input.emit(target, cam, ev, pos, norm, idx)
		if ev.is_action_pressed("interact"):
			Game.entity_interacted.emit(target)

func _mouse_enter():
	hovered = true

func _mouse_exit():
	hovered = false
