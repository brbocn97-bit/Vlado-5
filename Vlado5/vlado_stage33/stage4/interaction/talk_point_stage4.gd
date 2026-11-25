class_name TalkPointStage4
extends Stage4Interactable
## Named NPC with looping dialogue (Marko, Petar, Milica, Luka, Radoje, Vuk...).
## Builds a low-poly period figure that stands in for the Stage 4 cast, so the
## six regions feel populated before final character art exists.

@export var speaker_name := "Seljak"
@export var speaker_role := "Mještanin"
@export var style := "villager"     # villager | partisan | elder | axis | shepherd
@export var lines: Array[String] = []

var _index := 0
var _figure: Node3D


func _ready() -> void:
	kind = Kind.NPC_TALK
	prompt = "Razgovaraj: " + speaker_name
	one_shot = false
	super._ready()
	_build()


func _build() -> void:
	_figure = Node3D.new()
	_figure.name = "Figure"
	add_child(_figure)

	var cloth := "cloth_white"
	var head_key := "cloth_white"
	var hat := "wood_dark"
	match style:
		"partisan":
			cloth = "canvas_green"
			hat = "canvas_green"
		"axis":
			cloth = "canvas_axis"
			hat = "iron"
		"shepherd":
			cloth = "cloth_white"
			hat = "wood_dark"
		"elder":
			cloth = "cloth_white"
			hat = "wood_dark"
		_:
			cloth = "cloth_blue"

	var torso := Stage4Props.box(Vector3(0.44, 0.60, 0.26), cloth)
	torso.position = Vector3(0, 1.12, 0)
	_figure.add_child(torso)
	var belt := Stage4Props.box(Vector3(0.46, 0.07, 0.28), "wood_dark")
	belt.position = Vector3(0, 0.84, 0)
	_figure.add_child(belt)
	for s in [-1.0, 1.0]:
		var leg := Stage4Props.box(Vector3(0.16, 0.80, 0.19), "wood_dark")
		leg.position = Vector3(s * 0.11, 0.42, 0)
		_figure.add_child(leg)
		var boot := Stage4Props.box(Vector3(0.17, 0.15, 0.27), "wood_dark")
		boot.position = Vector3(s * 0.11, 0.075, 0.03)
		_figure.add_child(boot)
		var arm := Stage4Props.box(Vector3(0.12, 0.54, 0.14), cloth)
		arm.position = Vector3(s * 0.29, 1.14, 0)
		_figure.add_child(arm)
	var head := Stage4Props.sphere(0.15, head_key, false, 8)
	head.position = Vector3(0, 1.60, 0)
	head.scale = Vector3(0.9, 1.05, 0.9)
	_figure.add_child(head)
	var hat_mesh := Stage4Props.cyl(0.17, 0.10, hat, 0.20, 8)
	hat_mesh.position = Vector3(0, 1.74, 0)
	_figure.add_child(hat_mesh)
	if style == "elder" or style == "shepherd":
		var beard := Stage4Props.box(Vector3(0.14, 0.20, 0.10), "cloth_white")
		beard.position = Vector3(0, 1.48, 0.12)
		_figure.add_child(beard)
	if style == "partisan":
		var star := Stage4Props.box(Vector3(0.06, 0.06, 0.02), "cloth_red")
		star.position = Vector3(0, 1.66, 0.13)
		_figure.add_child(star)

	set_box(Vector3(1.15, 2.0, 1.15), Vector3(0, 1.0, 0))


func _do_interact(_by: Node3D) -> void:
	_used = false
	var line := "…"
	if not lines.is_empty():
		line = lines[_index % lines.size()]
		_index += 1
	notify("%s · %s" % [speaker_name, speaker_role], line)
	var ms := get_tree().root.get_node_or_null("MissionSystem")
	if ms and ms.has_method("notify_talk"):
		ms.notify_talk(speaker_name)


func _physics_process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var to: Vector3 = p.global_position - global_position
	to.y = 0
	if to.length() < 12.0 and to.length() > 0.4:
		_figure.rotation.y = lerp_angle(_figure.rotation.y, atan2(to.x, to.z), 0.08)
