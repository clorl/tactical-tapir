extends Node

signal entity_input(e: Entity3D, cam: Camera3D, event: InputEvent, event_pos: Vector3, normal: Vector3, shape_idx: int)
signal entity_interacted(e: Entity3D)
signal entity_hover_changed(e: Entity3D, hover: bool)

signal camera_focus(target: Vector3)

var party_controller: PartyController

func request_camera_focus(t: Vector3):
	camera_focus.emit(t)

class Data:
	const paths = {
		"characters": "res://character/characters.tres"
	}
	
	const Characters: Registry = preload(paths.characters)
