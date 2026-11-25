extends WorldRegion
## Region 5 — Kanjon Krupe i vodenica (southern gorge crossings).
## Enterable watermill with a turning paddlewheel, timber footbridge over the
## rapids, cobble ford (built by Stage4River), smuggler shelf and Miller Radoje.

const MILL := Vector2(-38.0, 272.0)
const FOOTBRIDGE_Z := 205.0
const SHELTER := Vector2(96.0, 300.0)


func build() -> void:
	region_id = "Krupa_Canyon_Crossings"
	focus_point = Vector2(40.0, 262.0)
	_build_watermill()
	_build_footbridge()
	_build_shelter()
	_build_canyon_detail()
	_build_waterfalls()
	_build_actors()


func _build_watermill() -> void:
	var house := Stage4Buildings.make_house_glb("zgrade/kuca_kamena.glb", "Vodenica")
	if house.is_empty():
		house = Stage4Buildings.make_house({
"width": 6.0, "depth": 5.0, "wall_height": 3.2, "roof_rise": 1.6,
		"wall_mat": "stone", "roof_mat": "slate", "door_side": 0,
		"windows": true, "chimney": false, "name": "Vodenica",
	})
	var root: Node3D = house["root"]
	place(root, MILL.x, MILL.y, 0.05)
	root.rotation.y = 1.35
	add_landmark(root)
	Stage4Buildings.furnish(house, "mill", [{
		"id": "clue_mill_ledger",
		"title": "Vodeničareva knjiga",
		"body": "„Za Nemce: 40 vreća žita, oduzeto bez potvrde. Za partizane: 12 vreća, noću preko gaza. Ako ovo čitaš, Radoje — ne dugujem nikome ništa osim Bogu i gladnima.“",
	}])

	# paddlewheel driven by the river
	var wheel_root := Node3D.new()
	wheel_root.name = "Paddlewheel"
	wheel_root.position = Vector3(3.3, 1.30, 1.0)
	root.add_child(wheel_root)
	var hub := Stage4Props.cyl(0.24, 0.40, "iron", -1, 8)
	hub.rotation.z = PI * 0.5
	wheel_root.add_child(hub)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var spoke := Stage4Props.box(Vector3(0.30, 1.55, 0.10), "wood_dark")
		spoke.position = Vector3(0, cos(a) * 0.78, sin(a) * 0.78)
		spoke.rotation.x = -a
		wheel_root.add_child(spoke)
		var paddle := Stage4Props.box(Vector3(0.42, 0.26, 0.42), "wood")
		paddle.position = Vector3(0, cos(a) * 1.55, sin(a) * 1.55)
		paddle.rotation.x = -a
		wheel_root.add_child(paddle)
	for r in 2:
		var rim := Stage4Props.cyl(1.58, 0.09, "wood", 1.58, 16)
		rim.rotation.z = PI * 0.5
		rim.position = Vector3(-0.18 + r * 0.36, 0, 0)
		wheel_root.add_child(rim)
	var spin := Timer.new()
	spin.wait_time = 0.03
	spin.autostart = true
	spin.timeout.connect(func(): wheel_root.rotation.x += 0.05)
	wheel_root.add_child(spin)

	for i in 4:
		var sack := Stage4Props.sphere(0.27, "hay", false, 8)
		place(sack, MILL.x - 4.2 + i * 0.5, MILL.y - 2.6, 0.0)
		sack.position.y += 0.33
		sack.scale = Vector3(1.0, 1.3, 1.0)
		add_detail(sack)


func _build_footbridge() -> void:
	var root := Node3D.new()
	root.name = "TimberFootbridge"
	var rx: float = terrain_data.get_river_center_x(FOOTBRIDGE_Z)
	var wy: float = terrain_data.get_river_water_y(FOOTBRIDGE_Z)
	root.position = Vector3(rx, wy + 2.15, FOOTBRIDGE_Z)
	root.rotation.y = 0.15

	for i in 9:
		var plank := Stage4Props.box(Vector3(1.5, 0.09, 0.42), "wood")
		plank.position = Vector3(0, 0, -3.6 + i * 0.9)
		plank.rotation.z = randf_range(-0.02, 0.02)
		root.add_child(plank)
	for s in [-1.0, 1.0]:
		var rail := Stage4Props.box(Vector3(0.10, 0.10, 8.0), "wood_dark")
		rail.position = Vector3(s * 0.72, 0.95, 0)
		root.add_child(rail)
		for i in 4:
			var post := Stage4Props.box(Vector3(0.10, 1.0, 0.10), "wood_dark")
			post.position = Vector3(s * 0.72, 0.5, -3.6 + i * 2.4)
			root.add_child(post)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = Stage4Props.box_shape(Vector3(1.8, 0.3, 8.2))
	body.add_child(cs)
	for s2 in [-1.0, 1.0]:
		var rcs := CollisionShape3D.new()
		rcs.shape = Stage4Props.box_shape(Vector3(0.12, 1.0, 8.0))
		rcs.position = Vector3(s2 * 0.72, 0.5, 0)
		body.add_child(rcs)
	root.add_child(body)
	add_landmark(root)


func _build_shelter() -> void:
	var root := Node3D.new()
	root.name = "SmugglerShelter"
	place(root, SHELTER.x, SHELTER.y, 0.0)
	root.rotation.y = -0.7
	var overhang := Stage4Props.box(Vector3(5.0, 0.78, 4.0), "stone_dark")
	overhang.position = Vector3(0, 2.55, -0.5)
	overhang.rotation.x = 0.12
	root.add_child(overhang)
	for i in 3:
		var rock := Stage4Props.sphere(1.1, "stone", false, 7)
		rock.position = Vector3(-2.0 + i * 2.0, 0.45, -1.8)
		rock.scale = Vector3(1.4, 1.7, 1.1)
		root.add_child(rock)
	for i in 2:
		var crate := Stage4Props.box(Vector3(0.68, 0.48, 0.48), "wood_dark")
		crate.position = Vector3(-1.2 + i * 1.1, 0.24, 0.6)
		root.add_child(crate)
	var lantern := Stage4Props.box(Vector3(0.15, 0.21, 0.15), "emissive_amber")
	lantern.position = Vector3(0.0, 1.08, 0.9)
	root.add_child(lantern)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.42)
	light.light_energy = 0.9
	light.omni_range = 5.0
	light.position = lantern.position + Vector3(0, 0.2, 0)
	root.add_child(light)
	add_landmark(root)

	var ammo := PickupStage4.new()
	ammo.visual = "ammo"
	ammo.ammo_amount = 25
	ammo.one_shot = false
	place(ammo, SHELTER.x, SHELTER.y + 1.2, 0.0)
	add_actor(ammo)
	var band := PickupStage4.new()
	band.visual = "bandage"
	band.heal_amount = 25.0
	band.one_shot = false
	place(band, SHELTER.x + 1.2, SHELTER.y + 0.8, 0.0)
	add_actor(band)


func _build_canyon_detail() -> void:
	# rim boulders framing the gorge (kept clear of the water and the trail)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400
	for i in 22:
		var x := rng.randf_range(-160.0, 220.0)
		var z := rng.randf_range(170.0, 600.0)
		if terrain_data.get_river_distance(x, z) < 16.0:
			continue
		var b := Stage4Props.sphere(rng.randf_range(0.6, 1.6), "stone", false, 7)
		place(b, x, z, 0.3)
		b.scale = Vector3(1.0, rng.randf_range(0.5, 0.9), 1.0)
		b.rotation.y = rng.randf() * TAU
		add_detail(b)


## Two falls drop off the canyon shelves into the Krupa. Both are placed against
## the real terrain: the lip is sampled from the heightfield and the falls are
## sized to the drop, so they never float or bury themselves.
func _build_waterfalls() -> void:
	# x is measured from the river centre line at that z, in metres
	var sites := [
		{"x": 15.5, "z": 268.0, "w": 3.8},   # just past the FordKanjonski crossing
		{"x": -14.0, "z": 392.0, "w": 2.6},  # deeper into the gorge
	]
	for site in sites:
		var x: float = site["x"]
		var z: float = site["z"]
		var w: float = site["w"]
		# Place on the canyon wall: the river centre at this z, offset sideways
		# by the requested amount so the water falls into the channel.
		var rx: float = terrain_data.get_river_center_x(z)
		var bank_x: float = rx + x
		var lip_y: float = terrain_data.get_height(bank_x, z)
		var water_y: float = terrain_data.get_river_water_y(z)
		var drop: float = maxf(3.0, lip_y - water_y)
		var root := Stage4Waterfall.new()
		root.name = "Waterfall_%d" % int(z)
		root.position = Vector3(bank_x, lip_y - 0.25, z)
		# face the curtain toward the river centre
		root.rotation.y = PI * 0.5 if x > rx else -PI * 0.5
		add_landmark(root)
		root.build(drop, w)
		# rocky frame around the lip
		for i in 5:
			var b := Stage4Props.sphere(0.5 + float(i % 3) * 0.35, "stone", false, 7)
			var ang := -0.7 + float(i) * 0.35
			b.position = Vector3(cos(ang) * (w * 0.62), 0.1, sin(ang) * (w * 0.55))
			b.scale = Vector3(1.2, 0.7, 1.0)
			root.add_child(b)
		print("[Stage4] waterfall at x=%.0f z=%.0f drop=%.1f m width=%.1f m" % [bank_x, z, drop, w])


func _build_actors() -> void:
	var radoje := TalkPointStage4.new()
	radoje.speaker_name = "Radoje"
	radoje.speaker_role = "Vodeničar"
	radoje.style = "elder"
	radoje.lines = [
		"Točak se vrti i kad nema nikoga da melje. Tako je od mog oca.",
		"Nemci su uzeli četrdeset vreća. Partizanima sam dao dvanaest, noću.",
		"Gaz je plitak ovih dana. Prođi bos — bolje nego da te vide na mostu.",
		"Čuvaj se na južnoj straži. Njih dvojica su na litici, gore.",
	]
	place(radoje, MILL.x + 5.2, MILL.y - 3.0, 0.0)
	add_actor(radoje)
