class_name HingedDoorStage4
extends Stage4Interactable
## Hinged door with a real swinging pivot + moving collider, so the player walks
## through the opening in both THIRD_PERSON and FIRST_PERSON modes.

@export var width := 1.10
@export var height := 2.10
@export var open_angle_deg := 102.0
@export var open_speed := 3.2
@export var door_key := "wood_dark"

var is_open := false
var _pivot: Node3D
var _leaf: Node3D
var _leaf_body: AnimatableBody3D
var _tween: Tween


func _ready() -> void:
	kind = Kind.DOOR
	prompt = "Otvori vrata"
	one_shot = false
	super._ready()
	_build()


func _build() -> void:
	_pivot = Node3D.new()
	_pivot.name = "DoorPivot"
	_pivot.position = Vector3(-width * 0.5, 0, 0)
	add_child(_pivot)

	_leaf = Node3D.new()
	_leaf.position = Vector3(width * 0.5, 0, 0)
	_pivot.add_child(_leaf)

	var panel := Stage4Props.box(Vector3(width, height, 0.075), door_key)
	panel.position = Vector3(0, height * 0.5, 0)
	_leaf.add_child(panel)

	for i in 3:
		var plank := Stage4Props.box(Vector3(width * 0.90, height * 0.26, 0.016), "wood")
		plank.position = Vector3(0, height * (0.18 + i * 0.30), 0.048)
		_leaf.add_child(plank)

	var handle := Stage4Props.sphere(0.045, "iron", false, 6)
	handle.position = Vector3(width * 0.36, height * 0.52, 0.09)
	_leaf.add_child(handle)

	for y in [height * 0.80, height * 0.18]:
		var hinge := Stage4Props.box(Vector3(0.06, 0.10, 0.10), "iron")
		hinge.position = Vector3(-width * 0.46, y, 0)
		_leaf.add_child(hinge)

	_leaf_body = AnimatableBody3D.new()
	_leaf_body.sync_to_physics = true
	_leaf_body.collision_layer = 1
	_leaf_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = Stage4Props.box_shape(Vector3(width, height, 0.10))
	cs.position = Vector3(0, height * 0.5, 0)
	_leaf_body.add_child(cs)
	_leaf.add_child(_leaf_body)

	set_box(Vector3(width + 0.40, height, 0.80), Vector3(0, height * 0.5, 0))


func _do_interact(_by: Node3D) -> void:
	_used = false
	toggle()


func toggle() -> void:
	is_open = not is_open
	prompt = "Zatvori vrata" if is_open else "Otvori vrata"
	var target := deg_to_rad(-open_angle_deg) if is_open else 0.0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(_pivot, "rotation:y", target, 1.0 / open_speed) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func set_open(open: bool, instant: bool = false) -> void:
	if instant:
		is_open = open
		_pivot.rotation.y = deg_to_rad(-open_angle_deg) if open else 0.0
		prompt = "Zatvori vrata" if is_open else "Otvori vrata"
	else:
		if is_open != open:
			toggle()
