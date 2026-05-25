extends Node
class_name PartyController

signal party_changed(p: Array[Character])
var active_character: CharacterEntity:
	set(v):
		if is_instance_valid(active_character):
			active_character.selected = false
		active_character = v
		active_character.selected = true
		_active_character_changed()

var party: Array[Character]:
	set(v):
		party = v
		_party_changed()

func _ready():
	Game.entity_interacted.connect(_entity_interact)

func _entity_interact(e):
	if e is CharacterEntity and e.character and party.has(e.character):
		get_viewport().set_input_as_handled()
		active_character = e


func _party_changed():
	party_changed.emit(party)

func _active_character_changed():
	Game.camera_focus.emit(active_character.global_position)
