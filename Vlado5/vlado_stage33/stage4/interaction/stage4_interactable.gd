class_name Stage4Interactable
extends Area3D
## Base class for every Stage 4 interactable.
##
## Layer 8 = interaction. Stage 3.2's weapon raycast only tests layer 1 (world),
## so interactables can never steal a bullet or block the M48 ballistics.

enum Kind { DOOR, PICKUP_AMMO, PICKUP_MEDKIT, CLUE_NOTE, NPC_TALK, CAMPFIRE, VANTAGE }

signal interacted(by: Node3D)

@export var kind: Kind = Kind.PICKUP_AMMO
@export var prompt: String = "Interaguj"
@export var one_shot := true

var _used := false
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	if _shape == null:
		_shape = CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.3, 2.0, 1.3)
		_shape.shape = bs
		_shape.position = Vector3(0, 1.0, 0)
		add_child(_shape)


func set_box(size: Vector3, centre: Vector3 = Vector3(0, 1.0, 0)) -> void:
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var bs := BoxShape3D.new()
	bs.size = size
	_shape.shape = bs
	_shape.position = centre


func get_prompt() -> String:
	if _used and one_shot:
		return ""
	return prompt


func on_interact(by: Node3D) -> void:
	if _used and one_shot:
		return
	_used = true
	interacted.emit(by)
	_do_interact(by)


func _do_interact(_by: Node3D) -> void:
	pass


## Route UI text through the Stage 3.2 DebugHUD if it supports Stage 4 banners.
func notify(title: String, body: String) -> void:
	var hud := get_tree().get_first_node_in_group("stage4_hud")
	if hud == null:
		hud = get_tree().current_scene.get_node_or_null("DebugHUD")
	if hud and hud.has_method("show_stage4_note"):
		hud.show_stage4_note(title, body)
	elif hud and hud.has_method("show_toast"):
		hud.show_toast(title)
	print("[Stage4] ", title, " — ", body)
