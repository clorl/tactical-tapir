@tool
class_name CharacterEntity extends Entity3D

var selected := false:
	set(v):
		selected = v
		_update_outline()

@onready var select_outline = $SelectOutline
@onready var hover_outline = $HoverOutline

func _ready():
	assert(select_outline)
	assert(hover_outline)
	if is_instance_valid($Interactable):
		$Interactable.hover_state_changed.connect(func(v): _update_outline())

var character: Character:
	set(v):
		character = v
		_data_updated()

func _data_updated():
	pass

func _update_outline():
	if selected:
		select_outline.enable()
	elif is_instance_valid($Interactable) and $Interactable.hovered:
		hover_outline.enable()
	else:
		select_outline.disable()
		hover_outline.disable()
