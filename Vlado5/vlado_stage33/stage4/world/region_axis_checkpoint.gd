extends WorldRegion
## Region 3 — Vojni punkt Raskršće (fortified pass on the east switchback).
## Boom barrier, chevaux-de-frise, sandbag nests, watchtower with ladder,
## enterable concrete pillbox, enterable guard barracks, mortar camp.

const COMPOUND := Vector2(340.0, -90.0)
const BARRIER := Vector2(278.0, -112.0)
const MORTAR := Vector2(452.0, -138.0)


func build() -> void:
	region_id = "Axis_Checkpoint"
	focus_point = Vector2(340.0, -90.0)
	_build_barrier()
	_build_tower()
	_build_pillbox()
	_build_barracks()
	_build_mortar_camp()
	_build_defences()


func _build_barrier() -> void:
	var root := Node3D.new()
	root.name = "BoomBarrier"
	place(root, BARRIER.x, BARRIER.y, 0.0)
	root.rotation.y = 0.5
	for s in [-1.0, 1.0]:
		var post := Stage4Props.box(Vector3(0.30, 1.22, 0.30), "concrete")
		post.position = Vector3(s * 3.0, 0.61, 0)
		root.add_child(post)
		var stripe := Stage4Props.box(Vector3(0.32, 0.20, 0.32), "cloth_white")
		stripe.position = Vector3(s * 3.0, 0.98, 0)
		root.add_child(stripe)
	var pivot := Node3D.new()
	pivot.position = Vector3(-3.0, 1.08, 0)
	root.add_child(pivot)
	var arm := Stage4Props.cyl(0.09, 6.0, "cloth_red", 0.09, 8)
	arm.rotation.z = PI * 0.5
	arm.position = Vector3(3.0, 0, 0)
	pivot.add_child(arm)
	for i in 5:
		var band := Stage4Props.cyl(0.10, 0.48, "cloth_white", -1, 8)
		band.rotation.z = PI * 0.5
		band.position = Vector3(0.8 + i * 1.1, 0, 0)
		pivot.add_child(band)
	pivot.rotation.z = -1.15
	add_landmark(root)

	for i in 6:
		var cd := Stage4Buildings.make_cheval_de_frise(2.2)
		place(cd, BARRIER.x - 6.0 + i * 2.3, BARRIER.y + 5.5, 0.1)
		cd.rotation.y = 0.5
		add_landmark(cd)
	for i in 4:
		var cd2 := Stage4Buildings.make_cheval_de_frise(2.2)
		place(cd2, BARRIER.x - 4.0 + i * 2.3, BARRIER.y - 5.0, 0.1)
		cd2.rotation.y = 0.5
		add_landmark(cd2)

	for i in 2:
		var nest := Stage4Buildings.make_sandbag_nest(1.5)
		place(nest, BARRIER.x - 8.0, BARRIER.y + (8.5 if i == 0 else -8.5), 0.0)
		add_landmark(nest)


func _build_tower() -> void:
	var tw := Stage4Buildings.make_watchtower(5.4)
	place(tw["root"], COMPOUND.x - 6.0, COMPOUND.y + 4.0, 0.0)
	tw["root"].rotation.y = -0.9
	add_landmark(tw["root"])
	var lamp := Stage4Props.box(Vector3(0.28, 0.28, 0.46), "iron")
	lamp.position = Vector3(0, 5.55, 1.15)
	tw["root"].add_child(lamp)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.92, 0.76)
	spot.light_energy = 2.0
	spot.spot_range = 38.0
	spot.spot_angle = 22.0
	spot.position = lamp.position + Vector3(0, 0.1, 0.2)
	tw["root"].add_child(spot)


func _build_pillbox() -> void:
	var pb := Stage4Buildings.make_house_glb("zgrade/kuca_kamena.glb", "PillboxBunker")
	if pb.is_empty():
		pb = Stage4Buildings.make_house({
"width": 4.6, "depth": 4.2, "wall_height": 2.35, "roof_rise": 0.30,
		"wall_mat": "concrete", "roof_mat": "concrete", "door_side": 3,
		"windows": false, "chimney": false, "name": "PillboxBunker",
	})
	place(pb["root"], COMPOUND.x + 7.0, COMPOUND.y - 3.0, 0.05)
	pb["root"].rotation.y = 1.9
	add_landmark(pb["root"])
	Stage4Buildings.furnish(pb, "pillbox")
	var slit := Stage4Props.box(Vector3(2.2, 0.32, 0.52), "dark_hole")
	slit.position = Vector3(0, 1.55, 2.10)
	pb["root"].add_child(slit)
	var lip := Stage4Props.box(Vector3(5.0, 0.26, 4.6), "stone_dark")
	lip.position = Vector3(0, 2.40, 0)
	pb["root"].add_child(lip)


func _build_barracks() -> void:
	var br := Stage4Buildings.make_house_glb("zgrade/supa_drvarnica.glb", "GuardBarracks")
	if br.is_empty():
		br = Stage4Buildings.make_house({
"width": 7.8, "depth": 5.4, "wall_height": 3.0, "roof_rise": 1.5,
		"wall_mat": "plaster", "roof_mat": "slate", "door_side": 0,
		"windows": true, "chimney": true, "name": "GuardBarracks",
	})
	place(br["root"], COMPOUND.x - 10.0, COMPOUND.y - 14.0, 0.05)
	br["root"].rotation.y = 0.35
	add_landmark(br["root"])
	Stage4Buildings.furnish(br, "barracks", [{
		"id": "clue_axis_dispatch",
		"title": "Naredba garnizona",
		"body": "GEHEIM: „Punkt Raskršće — pojačati stražu na mostu. Kamion sa municijom, 14:00 iz Bijelog Polja. Partizani viđeni kod Borove šume. Svaki civil bez propusnice zadržati.“ — Hauptmann Weber",
	}])

	var mast := Node3D.new()
	place(mast, COMPOUND.x - 15.0, COMPOUND.y - 11.0, 0.0)
	var pole := Stage4Props.cyl(0.07, 7.4, "iron", 0.04, 6)
	pole.position = Vector3(0, 3.7, 0)
	mast.add_child(pole)
	for i in 3:
		var arm := Stage4Props.box(Vector3(1.2, 0.05, 0.05), "iron")
		arm.position = Vector3(0, 3.5 + i * 1.4, 0)
		arm.rotation.z = 0.2 * (1.0 if i % 2 == 0 else -1.0)
		mast.add_child(arm)
	add_landmark(mast)


func _build_mortar_camp() -> void:
	var camp := Node3D.new()
	camp.name = "EastRidgeMortarCamp"
	place(camp, MORTAR.x, MORTAR.y, 0.05)
	var tent := Stage4Props.prism(Vector3(3.4, 1.9, 2.8), "canvas_axis")
	tent.rotation.y = 0.4
	camp.add_child(tent)
	var flap := Stage4Props.box(Vector3(1.0, 1.2, 0.06), "canvas_green")
	flap.position = Vector3(0, 0.6, 1.42)
	flap.rotation.y = 0.4
	camp.add_child(flap)
	var pit := Stage4Buildings.make_sandbag_nest(1.8)
	pit.position = Vector3(4.0, 0, 1.0)
	camp.add_child(pit)
	var base := Stage4Props.box(Vector3(0.54, 0.12, 0.54), "iron")
	base.position = Vector3(4.0, 0.55, 1.0)
	camp.add_child(base)
	var tube := Stage4Props.cyl(0.11, 1.1, "iron", 0.13, 8)
	tube.position = Vector3(4.0, 1.10, 1.0)
	tube.rotation.x = 0.6
	camp.add_child(tube)
	for i in 3:
		var c := Stage4Props.box(Vector3(0.58, 0.40, 0.44), "wood_dark")
		c.position = Vector3(-2.4 + i * 0.70, 0.20, 0.8)
		camp.add_child(c)
	add_landmark(camp)


func _build_defences() -> void:
	for i in 10:
		var a := PI * 0.15 + (PI * 0.9) * float(i) / 9.0
		var x := COMPOUND.x + cos(a) * 26.0
		var z := COMPOUND.y + sin(a) * 26.0
		var seg := Stage4Props.box(Vector3(3.4, 1.05, 0.78), "stone_dark")
		place(seg, x, z, 0.12)
		seg.position.y += 0.5
		seg.rotation.y = -a + PI * 0.5
		add_landmark(seg)

	var flag := Stage4Buildings.make_flag("cloth_red", 4.2)
	place(flag, COMPOUND.x - 2.0, COMPOUND.y + 10.0, 0.0)
	add_landmark(flag)

	var ammo := PickupStage4.new()
	ammo.visual = "ammo"
	ammo.ammo_amount = 20
	ammo.one_shot = false
	place(ammo, COMPOUND.x + 5.0, COMPOUND.y + 4.5, 0.0)
	add_actor(ammo)

	for i in 4:
		var crate := Stage4Props.box(Vector3(0.68, 0.44, 0.50), "wood_dark")
		place(crate, COMPOUND.x - 13.0 + (i % 2) * 0.8, COMPOUND.y - 17.0 + (i / 2) * 0.7, 0.0)
		crate.position.y += 0.22
		add_detail(crate)
