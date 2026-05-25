@tool
class_name Character extends Resource

const DEFAULT_ENTITY_SCENE := preload("res://character/character_entity.tscn")
@export var name: String
@export var portrait: Texture
@export var scene: PackedScene:
	get:
		if not scene: return DEFAULT_ENTITY_SCENE
		return scene

var entity: CharacterEntity

func spawn() -> CharacterEntity:
	assert(scene)
	var inst: CharacterEntity = scene.instantiate()
	if "character" in inst:
		inst.character = self
	if inst is CharacterEntity:
		entity = inst
	return inst
