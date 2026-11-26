class_name GermanSoldierModel
extends Node3D
## GermanSoldierModel — procedurally built Wehrmacht infantryman.
##
## The project ships no enemy character GLB, and the archive that would have
## carried one arrived corrupted, so this builds a low-poly soldier from the
## same primitive set Stage 4 already uses for buildings. That keeps the whole
## world in one visual language and costs ~2,600 triangles per soldier, which
## matters when a checkpoint fields six of them on a phone.
##
## Proportions follow the same 1.86 m height as Vlado so the two read as members
## of the same world. Field-grey uniform (Feldgrau), Y-straps, belt, jackboots,
## M35 steel helmet, and a Kar98k on the back.

const HEIGHT := 1.86

# Palette — real Wehrmacht 1941-43 tones, desaturated for the Balkan theatre
const C_FELDGRAU := Color(0.44, 0.47, 0.41)
const C_TROUSERS := Color(0.37, 0.39, 0.34)
const C_HELMET := Color(0.36, 0.38, 0.34)
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
	# ---- legs (pivoted at the hip so the walk cycle can swing them) --------
	left_leg = _leg(-0.13)
	right_leg = _leg(0.13)

	# ---- torso -------------------------------------------------------------
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.92, 0)
	add_child(torso)

	# tunic body
	_box(torso, Vector3(0.44, 0.56, 0.25), Vector3(0, 0.30, 0), C_FELDGRAU)
	# tunic skirt over the hips
	_box(torso, Vector3(0.46, 0.14, 0.27), Vector3(0, 0.03, 0), C_FELDGRAU)
	# collar
	_box(torso, Vector3(0.22, 0.07, 0.20), Vector3(0, 0.60, 0), Color(0.30, 0.32, 0.30))
	# belt
	_box(torso, Vector3(0.46, 0.07, 0.27), Vector3(0, 0.10, 0), C_LEATHER)
	# Y-straps
	_box(torso, Vector3(0.06, 0.42, 0.03), Vector3(-0.12, 0.36, -0.13), C_LEATHER, Vector3(0, 0, 6))
	_box(torso, Vector3(0.06, 0.42, 0.03), Vector3(0.12, 0.36, -0.13), C_LEATHER, Vector3(0, 0, -6))
	# magazine pouches
	for s in [-1.0, 1.0]:
		_box(torso, Vector3(0.10, 0.13, 0.07), Vector3(s * 0.15, 0.09, -0.14), C_LEATHER)
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
	# M35 helmet: dome + flared rim
	var dome := _sphere(head, 0.132, Vector3(0, 0.185, 0), C_HELMET, 10)
	dome.scale = Vector3(1.0, 0.86, 1.06)
	_cyl(head, 0.150, 0.035, Vector3(0, 0.150, 0), C_HELMET, Vector3.ZERO, 12)

	# ---- arms (pivoted at the shoulder) ------------------------------------
	left_arm = _arm(-1.0)
	right_arm = _arm(1.0)

	# ---- Kar98k slung across the back --------------------------------------
	rifle = Node3D.new()
	rifle.name = "Kar98k"
	rifle.position = Vector3(0.02, 0.46, 0.16)
	rifle.rotation_degrees = Vector3(0, 0, 34)
	torso.add_child(rifle)
	_box(rifle, Vector3(0.045, 0.90, 0.045), Vector3(0, 0, 0), C_WOOD)
	_box(rifle, Vector3(0.030, 0.42, 0.030), Vector3(0.0, 0.44, 0), C_METAL)
	_box(rifle, Vector3(0.055, 0.12, 0.075), Vector3(0, 0.10, 0), C_WOOD)


func _leg(side: float) -> Node3D:
	var hip := Node3D.new()
	hip.name = "Leg_%s" % ("L" if side < 0 else "R")
	hip.position = Vector3(side, 0.92, 0)
	add_child(hip)
	# thigh
	_box(hip, Vector3(0.17, 0.46, 0.19), Vector3(0, -0.23, 0), C_TROUSERS)
	# shin
	_box(hip, Vector3(0.15, 0.42, 0.16), Vector3(0, -0.66, 0), C_TROUSERS)
	# jackboot
	_box(hip, Vector3(0.16, 0.23, 0.17), Vector3(0, -0.84, 0), C_LEATHER)
	_box(hip, Vector3(0.17, 0.08, 0.27), Vector3(0, -0.925, 0.03), C_LEATHER)
	return hip


func _arm(side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.name = "Arm_%s" % ("L" if side < 0 else "R")
	shoulder.position = Vector3(side * 0.255, 0.50, 0)
	torso.add_child(shoulder)
	_box(shoulder, Vector3(0.115, 0.30, 0.135), Vector3(0, -0.15, 0), C_FELDGRAU)
	_box(shoulder, Vector3(0.10, 0.28, 0.115), Vector3(0, -0.42, 0), C_FELDGRAU)
	_sphere(shoulder, 0.055, Vector3(0, -0.57, 0), C_SKIN, 6)
	return shoulder
