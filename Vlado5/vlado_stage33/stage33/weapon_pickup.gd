class_name WeaponPickup
extends Area3D
## WeaponPickup — a historical weapon lying in the world, ready to be picked up.

@export var weapon_id := "mp40"
@export var ammo_reserve := -1
@export var spin := true
const PROMPT_TAKE := "UZMI"

@export var prompt_radius := 3.2

var arsenal: WeaponArsenal
var hud: ArsenalHUD
var _t := 0.0
var _taken := false
var _player_in := false
var _model: Node3D
var _mobile_btn: Button = null


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = prompt_radius
	cs.shape = sphere
	add_child(cs)
	_spawn_model()


func _resolve_weapon_info() -> Dictionary:
	if arsenal != null:
		var d := arsenal.def_for_id(weapon_id)
		if d != null:
			return {
				"slot": d.slot,
				"path": d.model_path,
				"len": d.target_length_m,
				"label": d.display_name,
				"id": d.id,
			}
	var low := weapon_id.to_lower()
	var path := "res://assets/weapons/Models/" + low + ".glb"
	var tlen := 1.0
	var slot := 1
	var lbl := weapon_id.to_upper()
	if low == "mp40":
		slot = 1
		tlen = 0.63
		lbl = "MP 40"
	elif low == "mg42" or low.begins_with("maschinen"):
		slot = 2
		path = "res://assets/weapons/Models/maschinengewehr_mg_42.glb"
		tlen = 1.22
		lbl = "MG 42"
	elif low == "gasser_m1870":
		slot = 3
		tlen = 0.30
		lbl = "Crnogorski Gaser M1870/74"
	elif low == "mauser_98" or low.begins_with("mauser_98"):
		slot = 4
		path = "res://assets/weapons/Models/mauser_98_sporting.glb"
		tlen = 1.11
		lbl = "Mauser 98k"
	return {"slot": slot, "path": path, "len": tlen, "label": lbl, "id": low}


func _strip_sketchfab_clutter(root_n: Node, wid: String) -> void:
	var bad_prefixes: Array[String] = []
	if wid == "mp40":
		bad_prefixes = ["Cube_001", "Cube_002", "Cube_003", "Cube_004", "Cylinder_001", "Cube_005", "Circle_001", "Camera"]
	elif wid == "mg42" or wid.begins_with("maschinen"):
		bad_prefixes = ["Plane_006", "BezierCurve_003"]
	elif wid.begins_with("mauser_98"):
		bad_prefixes = ["weapon#ammo_mesh_001_001", "weapon#ammo_mesh_001_002", "weapon#ammo_mesh_001_005", "weapon#ammo_mesh_001_006"]
	if bad_prefixes.is_empty():
		return
	var to_free: Array[Node] = []
	var stack: Array[Node] = [root_n]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var nm := String(n.name)
		var bad := false
		for p in bad_prefixes:
			if nm.begins_with(p):
				bad = true
				break
		if bad:
			to_free.append(n)
		else:
			for c in n.get_children():
				stack.append(c)
	for bn in to_free:
		if bn.get_parent():
			bn.get_parent().remove_child(bn)
		bn.free()


func _spawn_model() -> void:
	var info := _resolve_weapon_info()
	var path := str(info["path"])
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	_model = scene.instantiate() as Node3D
	_strip_sketchfab_clutter(_model, str(info["id"]))

	var raw := _combined_aabb(_model)
	var longest: float = maxf(raw.size.x, maxf(raw.size.y, raw.size.z))
	if longest <= 0.0001:
		add_child(_model)
		return
	var target: float = float(info["len"])
	var s := target / longest
	_model.scale = Vector3(s, s, s)

	var scaled := _combined_aabb(_model)
	_model.position = -scaled.get_center()

	var pivot := Node3D.new()
	pivot.name = "DisplayPivot"
	pivot.rotation_degrees = _lay_flat_rotation(scaled)
	pivot.add_child(_model)

	var flat := _combined_aabb(_model)
	pivot.position = Vector3(0.0, -flat.position.y, 0.0)
	add_child(pivot)

	var glow := MeshInstance3D.new()
	glow.name = "PickupRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.44
	glow.mesh = torus
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.85, 0.62, 0.22, 0.55)
	gm.emission_enabled = true
	gm.emission = Color(0.95, 0.62, 0.18)
	gm.emission_energy_multiplier = 0.55
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.material_override = gm
	glow.position = Vector3(0, 0.02, 0)
	add_child(glow)

	var light := OmniLight3D.new()
	light.name = "PickupLight"
	light.light_color = Color(1.0, 0.76, 0.42)
	light.light_energy = 0.35
	light.omni_range = 1.8
	light.position = Vector3(0, 0.5, 0)
	add_child(light)


func _lay_flat_rotation(a: AABB) -> Vector3:
	var sx := a.size.x
	var sy := a.size.y
	var sz := a.size.z
	if sy >= sx and sy >= sz:
		return Vector3(-90, 0, 0)
	if sx >= sz:
		return Vector3.ZERO
	return Vector3(0, 90, 0)


func _combined_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var start_xf := Transform3D.IDENTITY
	if n is Node3D:
		start_xf = (n as Node3D).transform
	var stack: Array = [[n, start_xf]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mi := node as MeshInstance3D
			var box: AABB = xf * mi.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for c in node.get_children():
			var child_xf: Transform3D = xf
			if c is Node3D:
				child_xf = xf * (c as Node3D).transform
			stack.append([c, child_xf])
	return out


func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	if spin and _model and not _player_in:
		_model.rotation.y += delta * 0.6
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var inside := false
	if p:
		var d := p.global_position.distance_to(global_position)
		inside = d <= prompt_radius + 0.6
	if inside != _player_in:
		_player_in = inside
		if hud:
			hud.set_prompt(PROMPT_TAKE if inside else "")
		_update_mobile_button(inside)


func _label() -> String:
	return str(_resolve_weapon_info()["label"])


func _on_body_entered(body: Node3D) -> void:
	if not body is PlayerController:
		return
	_player_in = true
	_update_mobile_button(true)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		_player_in = false
		_update_mobile_button(false)


func _unhandled_input(event: InputEvent) -> void:
	if _taken or not _player_in:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			take()
			get_viewport().set_input_as_handled()


func take() -> bool:
	if _taken or arsenal == null:
		return false
	var info := _resolve_weapon_info()
	var slot: int = int(info["slot"])
	arsenal.give_weapon(slot, ammo_reserve)
	arsenal.switch_to(slot)
	_taken = true
	if hud:
		hud.set_prompt("")
		hud.toast("Preuzeto: " + _label())
	_update_mobile_button(false)
	if _model:
		_model.queue_free()
		_model = null
	return true


func _update_mobile_button(show_it: bool) -> void:
	if show_it:
		_ensure_mobile_button()
		if _mobile_btn:
			_mobile_btn.visible = true
			_mobile_btn.text = "UZMI"
	elif _mobile_btn:
		_mobile_btn.visible = false


func _ensure_mobile_button() -> void:
	if _mobile_btn != null and is_instance_valid(_mobile_btn):
		return
	var layer := CanvasLayer.new()
	layer.name = "PickupLayer"
	layer.layer = 20
	add_child(layer)
	var b := Button.new()
	b.name = "PickupButton"
	b.text = "UZMI"
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	# Bottom-center clears both left joystick and right thumb combat buttons
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.anchor_left = 0.5
	b.anchor_top = 1.0
	b.anchor_right = 0.5
	b.anchor_bottom = 1.0
	b.offset_left = -88
	b.offset_top = -172
	b.offset_right = 88
	b.offset_bottom = -88
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.42, 0.16, 0.92)
	sb.border_color = Color(0.45, 0.85, 0.42, 1.0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(42)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.20, 0.62, 0.24, 1.0)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.pressed.connect(_on_mobile_pressed)
	layer.add_child(b)
	_mobile_btn = b


func _on_mobile_pressed() -> void:
	take()
