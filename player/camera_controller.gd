@tool
extends Node3D

@export var debug := false

@export var max_speed := 20.0
@export_range(0.1, 10) var camera_distance := 5.0:
	set(v):
		if cam_distance_range.x > 0 and v < cam_distance_range.x:
			camera_distance = cam_distance_range.x
		elif cam_distance_range.y > 0 and v > cam_distance_range.y:
			camera_distance = cam_distance_range.y
		else:
			camera_distance = v
		_update_camera_dist()

@export var cam_distance_range := Vector2(1, 20)

var velocity: Vector3
#var acceleration: Vector2
var target_velocity: Vector3

var cam: Node3D:
	get:
		return get_child(0)

var cam_tween: Tween

var should_rotate := false
var last_mouse_pos := Vector2()
var rot: Vector2

var target := Vector3():
	set(v):
		target = v
		_target_changed()
var tween: Tween

func _ready():
	self.target = global_position
	Game.camera_focus.connect(func(p): target = p)

func _target_changed():
	if not is_inside_tree(): return
	if tween:
		tween.kill()
	tween = get_tree().create_tween()
	tween.tween_property(self, "position", target, .5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(dt):
	if debug and target:
		DebugDraw3D.draw_sphere(target, .1, Color.RED)

	if Engine.is_editor_hint(): return

	if should_rotate:
		var dir = get_viewport().get_mouse_position() - last_mouse_pos
		global_rotation.y -= dir.x * dt
		global_rotation.x -= dir.y * dt
		global_rotation_degrees.x = clamp(global_rotation_degrees.x, -70, -10)
		last_mouse_pos = get_viewport().get_mouse_position()


	var input = Input.get_vector("cam_left", "cam_right", "cam_front", "cam_back")
	var dir = transform.basis.z * input.y + transform.basis.x * input.x
	dir.y = 0
	velocity = dir.normalized() * max_speed

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	target += velocity * dt

func _input(event):
	if event.is_action_pressed("cam_rotate_enable"):
		last_mouse_pos = get_viewport().get_mouse_position()
		should_rotate = true
	elif event.is_action_released("cam_rotate_enable"):
		should_rotate = false

	if event.is_action_pressed("cam_zoom_in"):
		camera_distance -= 1
	elif event.is_action_pressed("cam_zoom_out"):
		camera_distance += 1

func _update_camera_dist():
	if not is_inside_tree():
		cam.position.z = camera_distance
		return
	if cam_tween:
		cam_tween.kill()
	cam_tween = get_tree().create_tween()
	cam_tween.tween_property(cam, "position", Vector3(0, 0, camera_distance), .3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
