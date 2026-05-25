extends Node
class_name Level

@export var camera_scene: PackedScene
@export var party_controller_scene: PackedScene
@export_custom(Registry.PROPERTY_HINT_CUSTOM, Data.PATH_CHARACTERS) var party_ids: Array[StringName]

var party: Array[Character]

func _ready():
	assert(party_controller_scene)
	for id in party_ids:
		party.append(Data.Characters.load_entry(id))
	spawn_party()

	Game.party_controller = party_controller_scene.instantiate()
	Game.party_controller.party = party
	add_child(Game.party_controller)

func _exit_tree():
	Game.party_controller = null

func spawn_party():
	var spawns = get_tree().get_nodes_in_group("party_spawn")
	assert(spawns.size())
	for i in range(party.size()):
		var spawn_idx = i % spawns.size()
		var entity = party[i].spawn()
		add_child(entity)
		entity.global_position = spawns[spawn_idx].global_position
