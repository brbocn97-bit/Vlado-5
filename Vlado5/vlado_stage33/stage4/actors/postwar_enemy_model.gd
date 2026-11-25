class_name PostWarEnemyModel
extends Node3D
## PostWarEnemyModel — procedural low-poly post-war Yugoslav security-force proxy.
## This is a visual approximation, not a claim of exact documentary uniform detail.
##
## The project ships no enemy character GLB, and the archive that would have
## carried one arrived corrupted, so this builds a low-poly soldier from the
## same primitive set Stage 4 already uses for buildings. That keeps the whole
## world in one visual language and costs ~2,600 triangles per soldier, which
## matters when a checkpoint fields six of them on a phone.
##
## Proportions follow the same 1.86 m height as Vlado so the two read as members
## of the same world. The proxy uses a period-neutral field uniform and long rifle.

const HEIGHT := 1.86

# Simplified 1945+ Yugoslav/post-war field palette.
const C_UNIFORM := Color(0.34, 0.36, 0.29)
const C_TROUSERS := Color(0.31, 0.33, 0.28)
const C_HELMET := Color(0.31, 0.34, 0.30)
const C_LEATHER := Color(0.20, 0.16, 0.12)
const C_SKIN := Color(0.72, 0.58, 0.46)
const C_METAL := Color(0.22, 0.22, 0.23)
const C_WOOD := Color(0.40, 0.26, 0.15)

var head: Node3D
var torso: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var rifle: Node3D
var faction := "partizan"
var _mats: Dictionary = {}


func _ready() -> void:
	build()


func _mat(c: Color, metallic := 0.0, rough := 0.85) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [c.to_html(), metallic, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	_mats[key] = m
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO, seg := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.92
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, c: Color, seg := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = max(3, seg / 2)
	mi.mesh = sm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func build() -> void:
	if not get_children().is_empty():
		return
	var uniform_color := C_UNIFORM
	var trouser_color := C_TROUSERS
	var headgear_color := C_HELMET
	var equipment_color := C_LEATHER
	match faction:
		"partizan":
			uniform_color = Color(0.38, 0.41, 0.31)
			trouser_color = Color(0.31, 0.34, 0.28)
			headgear_color = Color(0.42, 0.43, 0.34)
			equipment_color = Color(0.27, 0.23, 0.17)
		"ozna":
			uniform_color = Color(0.28, 0.31, 0.27)
			trouser_color = Color(0.24, 0.27, 0.24)
			headgear_color = Color(0.20, 0.23, 0.20)
			equipment_color = Color(0.16, 0.14, 0.12)
		"udba":
			uniform_color = Color(0.22, 0.25, 0.23)
			trouser_color = Color(0.18, 0.21, 0.19)
			headgear_color = Color(0.12, 0.14, 0.13)
			equipment_color = Color(0.10, 0.10, 0.09)
	# ---- legs (pivoted at the hip so the walk cycle can swing them) --------
	left_leg = _leg(-0.13, trouser_color)
	right_leg = _leg(0.13, trouser_color)

	# ---- torso -------------------------------------------------------------
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.92, 0)
	add_child(torso)

	# tunic body
	_box(torso, Vector3(0.44, 0.56, 0.25), Vector3(0, 0.30, 0), uniform_color)
	# tunic skirt over the hips
	_box(torso, Vector3(0.46, 0.14, 0.27), Vector3(0, 0.03, 0), uniform_color)
	# collar
	_box(torso, Vector3(0.22, 0.07, 0.20), Vector3(0, 0.60, 0), Color(0.30, 0.32, 0.30))
	# belt
	_box(torso, Vector3(0.46, 0.07, 0.27), Vector3(0, 0.10, 0), equipment_color)
	# Y-straps
	_box(torso, Vector3(0.06, 0.42, 0.03), Vector3(-0.12, 0.36, -0.13), equipment_color, Vector3(0, 0, 6))
	_box(torso, Vector3(0.06, 0.42, 0.03), Vector3(0.12, 0.36, -0.13), equipment_color, Vector3(0, 0, -6))
	# magazine pouches
	for s in [-1.0, 1.0]:
		_box(torso, Vector3(0.10, 0.13, 0.07), Vector3(s * 0.15, 0.09, -0.14), equipment_color)
	# bread bag
	_box(torso, Vector3(0.16, 0.14, 0.08), Vector3(0.20, 0.06, 0.13), Color(0.34, 0.31, 0.24))
	# shoulder boards
	for s in [-1.0, 1.0]:
		_box(torso, Vector3(0.11, 0.04, 0.16), Vector3(s * 0.22, 0.55, 0), Color(0.30, 0.33, 0.29))

	# ---- head --------------------------------------------------------------
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.66, 0)
	torso.add_child(head)
	_cyl(head, 0.075, 0.09, Vector3(0, 0.02, 0), C_SKIN)          # neck
	_sphere(head, 0.115, Vector3(0, 0.155, 0.005), C_SKIN, 10)      # skull
	_box(head, Vector3(0.10, 0.045, 0.03), Vector3(0, 0.135, -0.10), Color(0.55, 0.63, 0.55))
	# Simplified post-war field helmet/cap proxy
	var dome := _sphere(head, 0.132, Vector3(0, 0.185, 0), headgear_color, 10)
	dome.scale = Vector3(1.0, 0.86, 1.06)
	_cyl(head, 0.150, 0.035, Vector3(0, 0.150, 0), headgear_color, Vector3.ZERO, 12)

	# ---- arms (pivoted at the shoulder) ------------------------------------
	left_arm = _arm(-1.0, uniform_color)
	right_arm = _arm(1.0, uniform_color)

	# ---- Long rifle slung across the back --------------------------------
	rifle = Node3D.new()
	rifle.name = "PostWarRifle"
	rifle.position = Vector3(0.02, 0.46, 0.16)
	rifle.rotation_degrees = Vector3(0, 0, 34)
	torso.add_child(rifle)
	_box(rifle, Vector3(0.045, 0.90, 0.045), Vector3(0, 0, 0), C_WOOD)
	_box(rifle, Vector3(0.030, 0.42, 0.030), Vector3(0.0, 0.44, 0), C_METAL)
	_box(rifle, Vector3(0.055, 0.12, 0.075), Vector3(0, 0.10, 0), C_WOOD)
	if faction == "ozna":
		_box(rifle, Vector3(0.08, 0.07, 0.08), Vector3(-0.09, 0.20, 0), C_METAL)
	elif faction == "udba":
		_box(rifle, Vector3(0.06, 0.18, 0.06), Vector3(0.0, 0.28, 0), C_METAL)
		_box(head, Vector3(0.035, 0.035, 0.08), Vector3(0.08, 0.155, -0.112), Color(0.55, 0.12, 0.10))


func _leg(side: float, trouser_color: Color) -> Node3D:
	var hip := Node3D.new()
	hip.name = "Leg_%s" % ("L" if side < 0 else "R")
	hip.position = Vector3(side, 0.92, 0)
	add_child(hip)
	# thigh
	_box(hip, Vector3(0.17, 0.46, 0.19), Vector3(0, -0.23, 0), trouser_color)
	# shin
	_box(hip, Vector3(0.15, 0.42, 0.16), Vector3(0, -0.66, 0), trouser_color)
	# jackboot
	_box(hip, Vector3(0.16, 0.23, 0.17), Vector3(0, -0.84, 0), C_LEATHER)
	_box(hip, Vector3(0.17, 0.08, 0.27), Vector3(0, -0.925, 0.03), C_LEATHER)
	return hip


func _arm(side: float, uniform_color: Color) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.name = "Arm_%s" % ("L" if side < 0 else "R")
	shoulder.position = Vector3(side * 0.255, 0.50, 0)
	torso.add_child(shoulder)
	_box(shoulder, Vector3(0.115, 0.30, 0.135), Vector3(0, -0.15, 0), uniform_color)
	_box(shoulder, Vector3(0.10, 0.28, 0.115), Vector3(0, -0.42, 0), uniform_color)
	_sphere(shoulder, 0.055, Vector3(0, -0.57, 0), C_SKIN, 6)
	return shoulder
