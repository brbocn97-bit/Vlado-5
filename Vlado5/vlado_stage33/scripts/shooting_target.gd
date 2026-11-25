class_name ShootingTarget
extends StaticBody3D

signal target_struck(target: ShootingTarget, distance_m: float)

@export var surface_kind: String = "metal"
@export var target_label: String = "Iron Gong"

var hit_count: int = 0
var _hinge: Node3D
var _plate_mat: StandardMaterial3D
var _recoil_deg: float = 0.0
var _recoil_vel: float = 0.0
var _flash_t: float = 0.0

static func spawn_range_in_world(parent: Node, terrain_data: MontenegroTerrainData, weapon_ctrl: Node) -> Array[ShootingTarget]:
	var specs := [
		{"x": -11.5, "z": -3.5, "yaw": 18.0, "kind": "wood", "name": "Trail Wood Target (14m)"},
		{"x": 4.2, "z": -4.8, "yaw": -28.0, "kind": "metal", "name": "Riverbank Gong (17m)"},
		{"x": -6.5, "z": -14.0, "yaw": 8.0, "kind": "metal", "name": "North Trail Plate (24m)"},
		{"x": -16.5, "z": -25.5, "yaw": 22.0, "kind": "wood", "name": "Pine Clearing Target (37m)"},
		{"x": 35.5, "z": -19.5, "yaw": -55.0, "kind": "metal", "name": "Bridge Far Gong (50m)"},
		{"x": -27.5, "z": -35.0, "yaw": 34.0, "kind": "metal", "name": "Ridge Outpost Plate (50m)"},
	]
	var out: Array[ShootingTarget] = []
	for i in specs.size():
		var s: Dictionary = specs[i]
		var tgt := ShootingTarget.new()
		tgt.name = "ShootingTarget_%d" % (i + 1)
		tgt.surface_kind = s["kind"]
		tgt.target_label = s["name"]
		var gy := terrain_data.get_height(float(s["x"]), float(s["z"]))
		tgt.position = Vector3(float(s["x"]), gy, float(s["z"]))
		tgt.rotation.y = deg_to_rad(float(s["yaw"]))
		parent.add_child(tgt)
		out.append(tgt)

	# Ammo resupply crate near spawn road edge
	var crate := AmmoCrate.new()
	crate.name = "AmmoResupplyCrate"
	var cx := -8.0
	var cz := 7.2
	crate.position = Vector3(cx, terrain_data.get_height(cx, cz), cz)
	crate.rotation.y = deg_to_rad(28.0)
	crate.setup(weapon_ctrl)
	parent.add_child(crate)

	return out

func _ready() -> void:
	collision_layer = 5 # bit 0 + bit 2 (world + shootable)
	collision_mask = 0

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.38, 0.27, 0.17)
	wood_mat.roughness = 0.88

	_plate_mat = StandardMaterial3D.new()
	if surface_kind == "metal":
		_plate_mat.albedo_color = Color(0.24, 0.26, 0.28)
		_plate_mat.metallic = 0.78
		_plate_mat.roughness = 0.42
	else:
		_plate_mat.albedo_color = Color(0.68, 0.56, 0.38)
		_plate_mat.roughness = 0.84

	# Support timber post
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.11, 1.35, 0.11)
	post.mesh = pm
	post.material_override = wood_mat
	post.position = Vector3(0.0, 0.675, 0.0)
	add_child(post)

	# Hinged target assembly
	_hinge = Node3D.new()
	_hinge.position = Vector3(0.0, 1.25, 0.0)
	add_child(_hinge)

	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.28
	cm.height = 0.045
	cm.radial_segments = 18
	disc.mesh = cm
	disc.material_override = _plate_mat
	disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	disc.position = Vector3(0.0, 0.18, 0.04)
	_hinge.add_child(disc)

	# Painted bullseye ring
	var bull := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.11
	bm.bottom_radius = 0.11
	bm.height = 0.052
	bm.radial_segments = 14
	bull.mesh = bm
	var bull_mat := StandardMaterial3D.new()
	bull_mat.albedo_color = Color(0.78, 0.20, 0.16)
	bull_mat.roughness = 0.6
	bull.material_override = bull_mat
	bull.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	bull.position = Vector3(0.0, 0.18, 0.04)
	_hinge.add_child(bull)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.30
	cyl.height = 0.12
	col.shape = cyl
	col.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	col.position = Vector3(0.0, 1.43, 0.04)
	add_child(col)

func register_hit(hit_pos: Vector3, shooter_pos: Vector3) -> float:
	hit_count += 1
	var dist := shooter_pos.distance_to(hit_pos)
	_recoil_vel = -290.0
	_flash_t = 0.35
	if _plate_mat:
		_plate_mat.emission_enabled = true
		_plate_mat.emission = Color(0.95, 0.72, 0.22)
		_plate_mat.emission_energy_multiplier = 1.2
	target_struck.emit(self, dist)
	return dist

func _process(delta: float) -> void:
	if absf(_recoil_deg) > 0.05 or absf(_recoil_vel) > 0.05:
		var spring_acc := -120.0 * _recoil_deg - 11.0 * _recoil_vel
		_recoil_vel += spring_acc * delta
		_recoil_deg = clampf(_recoil_deg + _recoil_vel * delta, -42.0, 16.0)
		if _hinge:
			_hinge.rotation.x = deg_to_rad(_recoil_deg)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0 and _plate_mat:
			_plate_mat.emission_enabled = false


class AmmoCrate extends Area3D:
	var _weapon_ctrl: Node
	var _cooldown: float = 0.0
	var _lid: MeshInstance3D

	func setup(wc: Node) -> void:
		_weapon_ctrl = wc

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2

		var box_mat := StandardMaterial3D.new()
		box_mat.albedo_color = Color(0.28, 0.34, 0.20)
		box_mat.roughness = 0.85

		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = Color(0.82, 0.68, 0.28)
		band_mat.metallic = 0.4
		band_mat.roughness = 0.45

		var base := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.72, 0.38, 0.44)
		base.mesh = bm
		base.material_override = box_mat
		base.position = Vector3(0.0, 0.19, 0.0)
		add_child(base)

		_lid = MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.76, 0.06, 0.48)
		_lid.mesh = lm
		_lid.material_override = box_mat
		_lid.position = Vector3(0.0, 0.40, 0.0)
		add_child(_lid)

		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.18, 0.07, 0.49)
		stripe.mesh = sm
		stripe.material_override = band_mat
		stripe.position = Vector3(0.0, 0.40, 0.0)
		add_child(stripe)

		var col := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.25
		col.shape = sp
		col.position = Vector3(0.0, 0.4, 0.0)
		add_child(col)
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		if _cooldown > 0.0:
			_cooldown -= delta

	func _on_body_entered(body: Node3D) -> void:
		if _cooldown > 0.0 or not (body is PlayerController):
			return
		if _weapon_ctrl and _weapon_ctrl.has_method("add_reserve_ammo"):
			var added: bool = _weapon_ctrl.add_reserve_ammo(15)
			if added:
				_cooldown = 8.0
				if _weapon_ctrl.has_method("play_reload_chime"):
					_weapon_ctrl.play_reload_chime()
