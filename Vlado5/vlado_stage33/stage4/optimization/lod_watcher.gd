class_name LODWatcher
extends Node
## LODWatcher — flips a mesh and its proxy based on camera distance.
##
## One instance per prop would be expensive, so the watcher only runs while the
## prop is inside a wide radius, and it samples on a 0.25 s cadence rather than
## every frame. With ~300 props that is 1,200 distance checks per second, which
## rounds to nothing on a phone.

const TICK := 0.25

var target: MeshInstance3D
var proxy: MeshInstance3D
var near_m := 90.0
var far_m := 340.0
var _timer := 0.0


func setup(p_target: MeshInstance3D, p_proxy: MeshInstance3D, p_near: float, p_far: float) -> void:
	target = p_target
	proxy = p_proxy
	near_m = p_near
	far_m = p_far
	_timer = randf() * TICK   # stagger so all props do not tick on the same frame


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	var p := target.get_parent() as Node3D
	if p and not p.is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(target.global_position)
	var show_real := d <= near_m
	target.visible = show_real if not _is_spawned_without_proxy() else true
	if proxy and is_instance_valid(proxy):
		proxy.visible = d > near_m and d <= far_m
	# past far_m everything is culled by the proxy's own hidden state
	if d > far_m:
		if proxy and is_instance_valid(proxy):
			proxy.visible = false


func _is_spawned_without_proxy() -> bool:
	return proxy == null or not is_instance_valid(proxy)
