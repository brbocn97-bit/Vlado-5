class_name MontenegroSettlement
extends Node3D

var night_lights: Array[Light3D] = []
var emissive_window_mats: Array[StandardMaterial3D] = []

var _stone_mat: StandardMaterial3D
var _slate_mat: StandardMaterial3D
var _wood_mat: StandardMaterial3D
var _dark_wood_mat: StandardMaterial3D
var _iron_mat: StandardMaterial3D

func build_settlement(data: MontenegroTerrainData) -> void:
	_init_materials()

	# 1. Main traditional Montenegrin stone house (Kuća)
	_build_stone_house(
		"MainStoneHouse",
		Vector3(-24.5, MontenegroTerrainData.VILLAGE_ELEV, 1.5),
		deg_to_rad(18.0),
		Vector3(7.6, 3.2, 5.8),
		true
	)

	# 2. Second hillside stone cottage
	_build_stone_house(
		"NorthStoneCottage",
		Vector3(-36.5, MontenegroTerrainData.VILLAGE_ELEV, -9.5),
		deg_to_rad(78.0),
		Vector3(6.2, 2.9, 5.0),
		true
	)

	# 3. Stone-and-timber barn / outbuilding (Konoba / Štala)
	_build_stone_barn(
		"VillageBarn",
		Vector3(-19.5, MontenegroTerrainData.VILLAGE_ELEV, 16.5),
		deg_to_rad(-12.0),
		Vector3(6.8, 3.0, 5.2)
	)

	# 4. Traditional stone village well (Bunar)
	_build_stone_well(Vector3(-16.5, MontenegroTerrainData.VILLAGE_ELEV, 5.2))

	# 5. Dry-stone perimeter walls (Međe) framing yard without blocking roads
	_build_dry_stone_wall(data, Vector2(-33.5, 8.5), Vector2(-24.5, 11.2), 1.05)
	_build_dry_stone_wall(data, Vector2(-33.5, -3.5), Vector2(-33.5, 8.5), 1.05)
	_build_dry_stone_wall(data, Vector2(-29.5, -15.5), Vector2(-18.5, -13.5), 1.0)
	_build_dry_stone_wall(data, Vector2(-14.5, 19.5), Vector2(-26.5, 22.0), 1.0)

	# 6. Stone-and-timber mountain river bridge at (23.53, 0, -16)
	_build_river_bridge(data)

func _init_materials() -> void:
	_stone_mat = StandardMaterial3D.new()
	_stone_mat.albedo_texture = load("res://assets/materials/polyhaven/old_stone_wall/albedo.jpg")
	_stone_mat.normal_enabled = true
	_stone_mat.normal_texture = load("res://assets/materials/polyhaven/old_stone_wall/normal_gl.jpg")
	_stone_mat.normal_scale = 1.2
	_stone_mat.roughness_texture = load("res://assets/materials/polyhaven/old_stone_wall/roughness.jpg")
	_stone_mat.uv1_triplanar = true
	_stone_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)

	_slate_mat = StandardMaterial3D.new()
	_slate_mat.albedo_texture = load("res://assets/textures/roof_slate_albedo.png")
	_slate_mat.normal_enabled = true
	_slate_mat.normal_texture = load("res://assets/textures/roof_slate_normal.png")
	_slate_mat.normal_scale = 1.05
	_slate_mat.roughness = 0.86
	_slate_mat.uv1_triplanar = true
	_slate_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)

	_wood_mat = StandardMaterial3D.new()
	_wood_mat.albedo_texture = load("res://assets/textures/wood_timber_albedo.png")
	_wood_mat.normal_enabled = true
	_wood_mat.normal_texture = load("res://assets/textures/wood_timber_normal.png")
	_wood_mat.normal_scale = 0.9
	_wood_mat.roughness = 0.85
	_wood_mat.uv1_triplanar = true
	_wood_mat.uv1_scale = Vector3(0.55, 0.55, 0.55)

	_dark_wood_mat = _wood_mat.duplicate()
	_dark_wood_mat.albedo_color = Color(0.62, 0.54, 0.46)

	_iron_mat = StandardMaterial3D.new()
	_iron_mat.albedo_color = Color(0.14, 0.14, 0.15)
	_iron_mat.roughness = 0.65
	_iron_mat.metallic = 0.45

func _make_window_mat() -> StandardMaterial3D:
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.16, 0.14, 0.12)
	wm.roughness = 0.35
	wm.emission = Color(0.95, 0.66, 0.28)
	wm.emission_enabled = false
	wm.emission_energy_multiplier = 0.0
	emissive_window_mats.append(wm)
	return wm

func _build_stone_house(node_name: String, origin: Vector3, yaw: float, size: Vector3, has_lantern: bool) -> void:
	var root := StaticBody3D.new()
	root.name = node_name
	root.position = origin
	root.rotation.y = yaw
	root.collision_layer = 1
	add_child(root)

	var w := size.x
	var h := size.y
	var d := size.z
	var roof_h := d * 0.44

	# Stone foundation plinth embedded below ground to prevent floating on edges
	_add_box_part(root, Vector3(0.0, -0.25, 0.0), Vector3(w + 0.36, 0.70, d + 0.36), _stone_mat, true)
	# Main rough-stone walls
	_add_box_part(root, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), _stone_mat, true)

	# Triangular stone gable end-walls along +X and -X ends
	var gable_mesh := _make_gable_mesh(w, d, roof_h)
	gable_mesh.surface_set_material(0, _stone_mat)
	var gable_mi := MeshInstance3D.new()
	gable_mi.mesh = gable_mesh
	gable_mi.position = Vector3(0.0, h, 0.0)
	root.add_child(gable_mi)

	# Slate pitched roof slabs overhanging walls
	var slope_len := sqrt((d * 0.5 + 0.55) * (d * 0.5 + 0.55) + roof_h * roof_h)
	var pitch := atan2(roof_h, d * 0.5)
	for side in [-1.0, 1.0]:
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w + 0.85, 0.18, slope_len)
		bm.material = _slate_mat
		slab.mesh = bm
		slab.position = Vector3(0.0, h + roof_h * 0.5 + 0.04, side * (d * 0.25 + 0.22))
		slab.rotation.x = side * pitch
		root.add_child(slab)

	# Timber ridge beam & eave beams
	_add_box_part(root, Vector3(0.0, h + roof_h + 0.04, 0.0), Vector3(w + 0.95, 0.20, 0.22), _dark_wood_mat, false)
	for side in [-1.0, 1.0]:
		_add_box_part(root, Vector3(0.0, h - 0.08, side * (d * 0.5 + 0.08)), Vector3(w + 0.3, 0.18, 0.18), _dark_wood_mat, false)

	# Stone chimney on roof
	_add_box_part(root, Vector3(w * 0.26, h + roof_h + 0.45, -d * 0.12), Vector3(0.75, 1.65, 0.75), _stone_mat, false)
	_add_box_part(root, Vector3(w * 0.26, h + roof_h + 1.32, -d * 0.12), Vector3(0.90, 0.12, 0.90), _slate_mat, false)

	# Oak plank front door (+Z facade) + grounded stone entry steps
	_add_box_part(root, Vector3(0.0, 1.10, d * 0.5 + 0.03), Vector3(1.12, 2.15, 0.12), _dark_wood_mat, false)
	_add_box_part(root, Vector3(0.0, 2.24, d * 0.5 + 0.06), Vector3(1.42, 0.18, 0.22), _stone_mat, false)
	_add_box_part(root, Vector3(0.0, -0.04, d * 0.5 + 0.42), Vector3(1.75, 0.52, 0.85), _stone_mat, true)

	# Shuttered timber windows with night hearth glow
	var w_mat := _make_window_mat()
	var win_positions := [
		Vector3(-w * 0.28, 1.55, d * 0.5 + 0.03),
		Vector3(w * 0.28, 1.55, d * 0.5 + 0.03),
		Vector3(-w * 0.24, 1.55, -d * 0.5 - 0.03),
		Vector3(w * 0.24, 1.55, -d * 0.5 - 0.03),
	]
	for wp in win_positions:
		_add_box_part(root, wp, Vector3(0.84, 0.92, 0.10), _dark_wood_mat, false)
		_add_box_part(root, wp + Vector3(0.0, 0.0, signf(wp.z) * 0.02), Vector3(0.64, 0.72, 0.08), w_mat, false)

	# Optional iron wall lantern beside front door
	if has_lantern:
		_attach_lantern(root, Vector3(0.95, 2.22, d * 0.5 + 0.35))

func _build_stone_barn(node_name: String, origin: Vector3, yaw: float, size: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = node_name
	root.position = origin
	root.rotation.y = yaw
	root.collision_layer = 1
	add_child(root)

	var w := size.x
	var h := size.y
	var d := size.z
	var roof_h := d * 0.40

	# Lower stone base + upper weathered timber walls
	_add_box_part(root, Vector3(0.0, 0.65, 0.0), Vector3(w + 0.25, 1.60, d + 0.25), _stone_mat, true)
	_add_box_part(root, Vector3(0.0, 1.45 + (h - 1.45) * 0.5, 0.0), Vector3(w, h - 1.45, d), _wood_mat, true)

	var gable_mesh := _make_gable_mesh(w, d, roof_h)
	gable_mesh.surface_set_material(0, _wood_mat)
	var gable_mi := MeshInstance3D.new()
	gable_mi.mesh = gable_mesh
	gable_mi.position = Vector3(0.0, h, 0.0)
	root.add_child(gable_mi)

	var slope_len := sqrt((d * 0.5 + 0.5) * (d * 0.5 + 0.5) + roof_h * roof_h)
	var pitch := atan2(roof_h, d * 0.5)
	for side in [-1.0, 1.0]:
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w + 0.75, 0.16, slope_len)
		bm.material = _slate_mat
		slab.mesh = bm
		slab.position = Vector3(0.0, h + roof_h * 0.5 + 0.03, side * (d * 0.25 + 0.20))
		slab.rotation.x = side * pitch
		root.add_child(slab)

	# Double barn doors + stacked timber logs along wall
	_add_box_part(root, Vector3(0.0, 1.25, -d * 0.5 - 0.04), Vector3(2.15, 2.35, 0.12), _dark_wood_mat, false)
	for lx in 4:
		var cyl := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.14
		cm.bottom_radius = 0.14
		cm.height = 1.65
		cm.radial_segments = 7
		cm.material = _dark_wood_mat
		cyl.mesh = cm
		cyl.position = Vector3(-w * 0.5 - 0.35, 0.22 + float(lx / 2) * 0.24, -0.6 + float(lx % 2) * 0.32)
		cyl.rotation.x = PI * 0.5
		root.add_child(cyl)

func _build_stone_well(origin: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = "VillageStoneWell"
	root.position = origin
	root.collision_layer = 1
	add_child(root)

	var ring_mi := MeshInstance3D.new()
	var ring_cm := CylinderMesh.new()
	ring_cm.top_radius = 0.92
	ring_cm.bottom_radius = 1.02
	ring_cm.height = 1.05
	ring_cm.radial_segments = 12
	ring_cm.material = _stone_mat
	ring_mi.mesh = ring_cm
	ring_mi.position.y = 0.42
	root.add_child(ring_mi)

	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 1.02
	cs.height = 1.2
	col.shape = cs
	col.position.y = 0.55
	root.add_child(col)

	for side in [-1.0, 1.0]:
		_add_box_part(root, Vector3(side * 0.85, 1.45, 0.0), Vector3(0.14, 1.55, 0.14), _dark_wood_mat, false)
	_add_box_part(root, Vector3(0.0, 2.15, 0.0), Vector3(1.95, 0.12, 0.12), _dark_wood_mat, false)
	for s in [-1.0, 1.0]:
		var roof := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.25, 0.10, 1.25)
		bm.material = _slate_mat
		roof.mesh = bm
		roof.position = Vector3(0.0, 2.48, s * 0.46)
		roof.rotation.x = s * 0.62
		root.add_child(roof)

func _build_dry_stone_wall(data: MontenegroTerrainData, a: Vector2, b: Vector2, height: float) -> void:
	var delta := b - a
	var length := delta.length()
	var mid := (a + b) * 0.5
	var wy := data.get_height(mid.x, mid.y)
	var yaw := atan2(-delta.y, delta.x)

	var body := StaticBody3D.new()
	body.name = "DryStoneWall"
	body.position = Vector3(mid.x, wy - 0.15, mid.y)
	body.rotation.y = yaw
	body.collision_layer = 1
	add_child(body)

	_add_box_part(body, Vector3(0.0, height * 0.5, 0.0), Vector3(length, height, 0.52), _stone_mat, true)
	_add_box_part(body, Vector3(0.0, height + 0.04, 0.0), Vector3(length + 0.08, 0.10, 0.60), _stone_mat, false)

func _build_river_bridge(data: MontenegroTerrainData) -> void:
	var center_x := MontenegroTerrainData.BRIDGE_CENTER.x
	var center_z := MontenegroTerrainData.BRIDGE_CENTER.y
	var deck_y := MontenegroTerrainData.BRIDGE_DECK_Y

	var root := StaticBody3D.new()
	root.name = "MountainRiverBridge"
	root.position = Vector3(center_x, 0.0, center_z)
	root.collision_layer = 1
	add_child(root)

	# 3 solid masonry piers standing in riverbed
	for px in [-6.8, 0.0, 6.8]:
		_add_box_part(root, Vector3(px, 0.1, 0.0), Vector3(1.55, 4.1, 4.9), _stone_mat, true)

	# Central timber-and-stone bridge deck (14.4 m span, 4.5 m wide)
	_add_box_part(root, Vector3(0.0, deck_y - 0.16, 0.0), Vector3(14.6, 0.32, 4.5), _wood_mat, true)
	# Heavy timber guardrails on north/south bridge sides
	for gz in [-2.05, 2.05]:
		_add_box_part(root, Vector3(0.0, deck_y + 0.85, gz), Vector3(14.6, 0.14, 0.16), _dark_wood_mat, true)
		_add_box_part(root, Vector3(0.0, deck_y + 0.45, gz), Vector3(14.6, 0.10, 0.12), _dark_wood_mat, false)
		for post_x in [-7.0, -3.5, 0.0, 3.5, 7.0]:
			_add_box_part(root, Vector3(post_x, deck_y + 0.48, gz), Vector3(0.22, 1.05, 0.22), _dark_wood_mat, true)

	# Smooth walk-on stone/timber approach ramps anchored into both riverbanks
	for side in [-1.0, 1.0]:
		var bank_h := data.get_height(center_x + side * 13.5, center_z)
		var drop := deck_y - bank_h
		var ramp_len := 6.6
		var pitch := atan2(drop, ramp_len)
		var ramp_body := StaticBody3D.new()
		ramp_body.position = Vector3(side * (7.3 + ramp_len * 0.47), deck_y - drop * 0.5 - 0.14, 0.0)
		ramp_body.rotation.z = -side * pitch
		ramp_body.collision_layer = 1
		root.add_child(ramp_body)
		_add_box_part(ramp_body, Vector3.ZERO, Vector3(ramp_len + 0.5, 0.34, 4.45), _stone_mat, true)

	# 2 warm iron bridge post lanterns glowing at Dusk / Night
	_attach_lantern(root, Vector3(-7.0, deck_y + 1.25, 2.05))
	_attach_lantern(root, Vector3(7.0, deck_y + 1.25, -2.05))

func _attach_lantern(parent: Node3D, local_pos: Vector3) -> void:
	_add_box_part(parent, local_pos + Vector3(0.0, 0.28, 0.0), Vector3(0.14, 0.06, 0.14), _iron_mat, false)
	_add_box_part(parent, local_pos + Vector3(0.0, 0.04, 0.0), Vector3(0.14, 0.05, 0.14), _iron_mat, false)
	var bulb := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.065
	cm.bottom_radius = 0.055
	cm.height = 0.20
	cm.radial_segments = 6
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.68, 0.58, 0.36)
	gmat.emission = Color(1.0, 0.68, 0.28)
	gmat.emission_enabled = false
	emissive_window_mats.append(gmat)
	cm.material = gmat
	bulb.mesh = cm
	bulb.position = local_pos + Vector3(0.0, 0.16, 0.0)
	parent.add_child(bulb)

	var omni := OmniLight3D.new()
	omni.position = local_pos
	omni.light_color = Color(1.0, 0.72, 0.38)
	omni.light_energy = 0.0
	omni.omni_range = 12.0
	omni.omni_attenuation = 1.4
	omni.shadow_enabled = false
	omni.visible = false
	parent.add_child(omni)
	night_lights.append(omni)

func _add_box_part(parent: CollisionObject3D, pos: Vector3, size: Vector3, mat: Material, with_collision: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)

	if with_collision:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		col.shape = bs
		col.position = pos
		parent.add_child(col)

func _make_gable_mesh(w: float, d: float, roof_h: float) -> ArrayMesh:
	var hw := w * 0.5
	var hd := d * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Left/Right triangular gable faces (-X and +X)
	for sx_raw in [-1.0, 1.0]:
		var sx: float = float(sx_raw)
		var x: float = sx * hw
		var p_front := Vector3(x, 0.0, hd)
		var p_back := Vector3(x, 0.0, -hd)
		var p_peak := Vector3(x, roof_h, 0.0)
		var n := Vector3(sx, 0.0, 0.0)
		if sx > 0.0:
			_tri(st, p_front, p_back, p_peak, n, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0))
		else:
			_tri(st, p_back, p_front, p_peak, n, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0))

	return st.commit()

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_uv(uc)
	st.add_vertex(c)
