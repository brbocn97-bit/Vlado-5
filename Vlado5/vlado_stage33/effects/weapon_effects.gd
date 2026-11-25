class_name WeaponEffects
extends RefCounted

static func _get_mats(parent: Node) -> Dictionary:
	if parent and parent.has_meta("_vlado_vfx_mats"):
		return parent.get_meta("_vlado_vfx_mats")
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.85, 0.38)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.72, 0.25)
	flash_mat.emission_energy_multiplier = 4.2
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var tracer_mat := StandardMaterial3D.new()
	tracer_mat.albedo_color = Color(1.0, 0.90, 0.52, 0.92)
	tracer_mat.emission_enabled = true
	tracer_mat.emission = Color(1.0, 0.82, 0.35)
	tracer_mat.emission_energy_multiplier = 3.0
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.albedo_color = Color(0.78, 0.77, 0.74, 0.45)
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.roughness = 0.95

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.76, 0.60, 0.24)
	brass_mat.metallic = 0.85
	brass_mat.roughness = 0.28

	var imp_spark := StandardMaterial3D.new()
	imp_spark.albedo_color = Color(1.0, 0.78, 0.35)
	imp_spark.emission_enabled = true
	imp_spark.emission = Color(1.0, 0.65, 0.22)
	imp_spark.emission_energy_multiplier = 2.5

	var imp_wood := StandardMaterial3D.new()
	imp_wood.albedo_color = Color(0.55, 0.38, 0.22)
	imp_wood.roughness = 0.9

	var imp_dirt := StandardMaterial3D.new()
	imp_dirt.albedo_color = Color(0.46, 0.36, 0.25)
	imp_dirt.roughness = 0.95

	var bm_chip := BoxMesh.new()
	bm_chip.size = Vector3(0.025, 0.025, 0.025)
	var bm_spark := BoxMesh.new()
	bm_spark.size = Vector3(0.015, 0.015, 0.06)

	var mats := {
		"flash": flash_mat,
		"tracer": tracer_mat,
		"smoke": smoke_mat,
		"brass": brass_mat,
		"imp_spark": imp_spark,
		"imp_wood": imp_wood,
		"imp_dirt": imp_dirt,
		"bm_chip": bm_chip,
		"bm_spark": bm_spark,
	}
	if parent:
		parent.set_meta("_vlado_vfx_mats", mats)
	return mats

static func spawn_muzzle_flash(parent: Node, pos: Vector3, dir: Vector3) -> void:
	var mats := _get_mats(parent)
	var fx := _FlashFX.new()
	parent.add_child(fx)
	if dir.length_squared() > 1e-4:
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		fx.look_at_from_position(pos, pos + dir, up)
	else:
		fx.global_position = pos

	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.075
	cm.height = 0.26
	cm.radial_segments = 6
	cone.mesh = cm
	cone.material_override = mats["flash"]
	cone.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cone.position = Vector3(0.0, 0.0, -0.13)
	fx.add_child(cone)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.78, 0.40)
	light.light_energy = 2.6
	light.omni_range = 4.5
	fx.add_child(light)

	var puff := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.radial_segments = 6
	sm.rings = 4
	puff.mesh = sm
	puff.material_override = mats["smoke"]
	puff.position = Vector3(0.0, 0.04, -0.18)
	fx.add_child(puff)

	fx.setup(cone, light, puff)

static func spawn_tracer(parent: Node, start_pos: Vector3, end_pos: Vector3) -> void:
	var mats := _get_mats(parent)
	var seg := end_pos - start_pos
	var dist := seg.length()
	if dist < 0.2:
		return
	var tr := _TracerFX.new()
	parent.add_child(tr)
	var mid := (start_pos + end_pos) * 0.5
	var up := Vector3.UP if absf(seg.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	tr.look_at_from_position(mid, end_pos, up)

	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = minf(dist, 55.0)
	cm.radial_segments = 4
	mi.mesh = cm
	mi.material_override = mats["tracer"]
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	tr.add_child(mi)

static func spawn_impact(parent: Node, pos: Vector3, normal: Vector3, surface: String) -> void:
	var mats := _get_mats(parent)
	var imp := _ImpactFX.new()
	parent.add_child(imp)
	imp.global_position = pos + normal * 0.02
	imp.setup(normal, surface, mats)

static func spawn_shell_casing(parent: Node, pos: Vector3, right_dir: Vector3, up_dir: Vector3) -> void:
	var mats := _get_mats(parent)
	var sh := _ShellFX.new()
	parent.add_child(sh)
	sh.global_position = pos
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.007
	cm.height = 0.056
	cm.radial_segments = 6
	mi.mesh = cm
	mi.material_override = mats["brass"]
	sh.add_child(mi)
	sh.vel = right_dir.normalized() * 2.2 + up_dir.normalized() * 2.5 + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))

class _FlashFX extends Node3D:
	var _t := 0.0
	var _cone: MeshInstance3D
	var _light: OmniLight3D
	var _puff: MeshInstance3D

	func setup(c: MeshInstance3D, l: OmniLight3D, p: MeshInstance3D) -> void:
		_cone = c
		_light = l
		_puff = p

	func _process(delta: float) -> void:
		_t += delta
		if _cone:
			_cone.visible = _t < 0.055
		if _light:
			_light.light_energy = maxf(0.0, 2.6 * (1.0 - _t / 0.07))
		if _puff:
			var s := 1.0 + _t * 6.5
			_puff.scale = Vector3(s, s, s)
			_puff.position.y += delta * 0.45
		if _t >= 0.32:
			queue_free()

class _TracerFX extends Node3D:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t >= 0.08:
			queue_free()

class _ImpactFX extends Node3D:
	var _t := 0.0
	var _chips: Array[MeshInstance3D] = []
	var _vels: Array[Vector3] = []

	func setup(normal: Vector3, surface: String, mats: Dictionary) -> void:
		var mat: StandardMaterial3D = mats["imp_spark"] if (surface == "metal" or surface == "stone") else (mats["imp_wood"] if surface == "wood" else mats["imp_dirt"])
		var bm: BoxMesh = mats["bm_spark"] if surface == "metal" else mats["bm_chip"]
		for _i in 6:
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = mat
			add_child(mi)
			_chips.append(mi)
			var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 1.4), randf_range(-1.0, 1.0))
			_vels.append((normal * 2.5 + jitter).normalized() * randf_range(2.2, 4.8))

	func _process(delta: float) -> void:
		_t += delta
		for i in _chips.size():
			_vels[i].y -= 9.8 * delta
			_chips[i].position += _vels[i] * delta
			_chips[i].rotation += Vector3(6.0, 8.0, 4.0) * delta
		if _t >= 0.38:
			queue_free()

class _ShellFX extends Node3D:
	var vel := Vector3.ZERO
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		vel.y -= 9.8 * delta
		global_position += vel * delta
		rotation += Vector3(14.0, 9.0, 11.0) * delta
		if _t >= 0.95:
			queue_free()
