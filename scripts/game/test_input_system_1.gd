extends Node

@export var mouse_sensitivity : float = 0.002
@export var mouse_look_key_bind : InputEventKey
@export var camera_distance : float = 2.5

@onready var CAMERA_ANCHOR := %CameraAnchor
@onready var CAMERA := %Camera3D

var rot_x : float = 0.0
var rot_y : float = 0.0

func _ready() -> void:
	CAMERA.position = Vector3(0, 0, camera_distance)
	CAMERA.rotation = Vector3.ZERO
	
	var current_rotation = CAMERA_ANCHOR.global_transform.basis.get_euler()
	rot_x = current_rotation.y
	rot_y = current_rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_key_pressed(mouse_look_key_bind.keycode):
			var mouse_movement : Vector2 = event.relative
			
			rot_x += -mouse_movement.x * mouse_sensitivity
			rot_y += -mouse_movement.y * mouse_sensitivity
			
			rot_y = clamp(rot_y, deg_to_rad(-89), deg_to_rad(89))
			
			var q_yaw := Quaternion(Vector3.UP, rot_x)
			var q_pitch := Quaternion(Vector3.RIGHT, rot_y)
			
			CAMERA_ANCHOR.global_transform.basis = Basis(q_yaw * q_pitch)
