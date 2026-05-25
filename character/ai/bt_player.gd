extends Node
class_name BTPlayer

@export var bt: BehaviourTree

func _ready():
	tick()

func tick():
	while true:
		var res = bt.tick()
		if res == BehaviourTree.Status.EXIT: return
		await get_tree().create_timer(.5).timeout
