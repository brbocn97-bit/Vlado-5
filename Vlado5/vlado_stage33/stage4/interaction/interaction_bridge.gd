class_name InteractionBridge
extends Node
## InteractionBridge — connects the Stage 3.2 input / camera to Stage 4 prompts.
##
## The Stage 3.2 player already handles movement, aiming and firing; it has no
## concept of "interactables". Rather than rewrite PlayerController, this node
## raycasts from the active camera once per frame, finds the nearest
## Stage4Interactable within reach, shows its prompt and dispatches G / E / the
## touch ACT button to it.

const RANGE := 3.2
const RAY_MASK := 1 | 8       # world + interaction layer only

@export var prompt_visible := true

var player: Node3D
var camera_rig: PlayerCamera
var current_target: Stage4Interactable = null
var _ray: RayCast3D
var _hud: Node


func setup(p_player: Node3D, p_camera_rig: PlayerCamera, p_hud: Node) -> void:
	player = p_player
	camera_rig = p_camera_rig
	_hud = p_hud
	_build_ray()


func _build_ray() -> void:
	_ray = RayCast3D.new()
	_ray.name = "InteractRay"
	_ray.target_position = Vector3(0, 0, -RANGE)
	_ray.collision_mask = RAY_MASK
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = true
	_ray.enabled = false
	add_child(_ray)


func _physics_process(_delta: float) -> void:
	if player == null or camera_rig == null or _ray == null:
		return
	var cam := camera_rig.get_camera()
	if cam == null:
		return
	# Pomjeri pocetak zraka do ravni igraca u TPS-u da kamera iza ledja ne pojede domet
	var xform := cam.global_transform
	if not camera_rig.is_fp_active():
		var fwd := -xform.basis.z
		var to_player := (player.global_position + Vector3(0.0, 1.35, 0.0)) - xform.origin
		xform.origin += fwd * maxf(0.0, to_player.dot(fwd))
	_ray.global_transform = xform
	_ray.force_raycast_update()

	var found: Stage4Interactable = null
	var collider := _ray.get_collider()
	if collider is Stage4Interactable:
		found = collider
	elif collider is Node:
		found = _find_interactable_parent(collider as Node)

	if found != current_target:
		current_target = found
		_push_prompt()


func _find_interactable_parent(node: Node) -> Stage4Interactable:
	var n := node
	for i in 4:
		if n == null:
			return null
		if n is Stage4Interactable:
			return n
		n = n.get_parent()
	return null


func _push_prompt() -> void:
	var text := ""
	if current_target and is_instance_valid(current_target):
		text = current_target.get_prompt()
	if _hud and _hud.has_method("set_stage4_prompt"):
		_hud.set_stage4_prompt(text)
	elif _hud and _hud.has_method("show_toast") and text != "":
		_hud.show_toast("[G] " + text)


func _unhandled_input(event: InputEvent) -> void:
	# G and E both interact; the Stage 3.2 build binds VIEW to E too, so G is
	# the primary Stage 4 key and E only fires when nothing is being viewed.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			interact()
		elif event.keycode == KEY_E and current_target != null:
			# only claim E when there is actually something to interact with
			interact()
			get_viewport().set_input_as_handled()


func interact() -> void:
	if current_target and is_instance_valid(current_target):
		current_target.on_interact(player)
		_push_prompt()
