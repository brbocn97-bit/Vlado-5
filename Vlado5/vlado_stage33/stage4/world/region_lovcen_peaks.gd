extends WorldRegion
## Region 6 — Crni vrh i katuni (Lovćen high peaks).
## Shepherd's stone katun + sheepfold, ruined medieval Kula with a climbable
## parapet, and the fictional post-war security relay camp. Shepherd Vuk keeps the katun.

const KATUN := Vector2(360.0, 292.0)
const KULA := Vector2(404.0, 336.0)
const RELAY := Vector2(432.0, 248.0)


func build() -> void:
	region_id = "Lovcen_High_Peaks"
	focus_point = Vector2(382.0, 314.0)
	_build_katun()
	_build_kula()
	_build_relay()
	_build_alpine_detail()
	_build_actors()


func _build_katun() -> void:
	var katun := Stage4Buildings.make_house_glb("zgrade/kuca_brvnara.glb", "ShepherdsStoneKatun")
	if katun.is_empty():
		katun = Stage4Buildings.make_house({
"width": 6.2, "depth": 5.2, "wall_height": 2.6, "roof_rise": 1.5,
		"wall_mat": "stone", "roof_mat": "slate", "door_side": 0,
		"windows": true, "chimney": true, "name": "ShepherdsStoneKatun",
	})
	place(katun["root"], KATUN.x, KATUN.y, 0.05)
	katun["root"].rotation.y = 0.22
	add_landmark(katun["root"])
	Stage4Buildings.furnish(katun, "katun", [{
		"id": "clue_katun_notes",
		"title": "Vukova bilješka",
		"body": "„Crni vrh, treći dan. Nemci grade radio stanicu na južnoj strani. Antena visoka kao tri čovjeka. Svako jutro u šest javljaju se. Ako ih zaustavimo, slijepi su.“",
	}])

	# sheepfold
	var pen := Node3D.new()
	pen.name = "Sheepfold"
	pen.position = katun["root"].position + Vector3(6.5, 0, 2.0)
	pen.rotation.y = 0.22
	var pen_r := 4.0
	for i in 12:
		var a := TAU * float(i) / 12.0
		var stone := Stage4Props.box(Vector3(2.3, 0.85, 0.5), "stone")
		stone.position = Vector3(cos(a) * pen_r, 0.42, sin(a) * pen_r)
		stone.rotation.y = -a + PI * 0.5
		pen.add_child(stone)
	add_landmark(pen)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 5:
		var sheep := Node3D.new()
		sheep.position = pen.position + Vector3(rng.randf_range(-2.5, 2.5), 0.55, rng.randf_range(-2.5, 2.5))
		var wool := Stage4Props.sphere(0.40, "cloth_white", false, 8)
		wool.scale = Vector3(1.3, 0.9, 1.0)
		sheep.add_child(wool)
		var head := Stage4Props.sphere(0.17, "wood_dark", false, 6)
		head.position = Vector3(0.48, 0.1, 0)
		sheep.add_child(head)
		add_detail(sheep)


func _build_kula() -> void:
	var root := Node3D.new()
	root.name = "RuinedKula"
	place(root, KULA.x, KULA.y, 0.0)
	root.rotation.y = -0.4
	var radius := 2.55
	var height := 9.4
	for level in 3:
		var y := level * 3.1
		var r := radius - level * 0.22
		for i in 10:
			if level == 2 and (i == 3 or i == 4):
				continue   # broken parapet gap
			var a := TAU * float(i) / 10.0
			var stone := Stage4Props.box(Vector3(1.72, 3.0, 0.54), "stone" if i % 2 == 0 else "stone_dark")
			stone.position = Vector3(cos(a) * r, y + 1.5, sin(a) * r)
			stone.rotation.y = -a + PI * 0.5
			root.add_child(stone)
	for i in 10:
		if i == 6 or i == 7:
			continue
		var a2 := TAU * float(i) / 10.0
		var merlon := Stage4Props.box(Vector3(0.90, 0.54, 0.50), "stone_light")
		merlon.position = Vector3(cos(a2) * (radius - 0.65), height + 0.27, sin(a2) * (radius - 0.65))
		merlon.rotation.y = -a2 + PI * 0.5
		root.add_child(merlon)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0

	# Suplji kameni zidovi (indeks 0 na nivou 0 ostaje otvoren ulaz!)
	for level in 3:
		var y := level * 3.1
		var r := radius - level * 0.22
		for i in 10:
			if (level == 0 and i == 0) or (level == 2 and (i == 3 or i == 4)):
				continue
			var a := TAU * float(i) / 10.0
			var wcs := CollisionShape3D.new()
			wcs.shape = Stage4Props.box_shape(Vector3(1.72, 3.0, 0.54))
			wcs.position = Vector3(cos(a) * r, y + 1.5, sin(a) * r)
			wcs.rotation.y = -a + PI * 0.5
			body.add_child(wcs)

	# walkable block steps with real step colliders
	for k in 8:
		var step := Stage4Props.box(Vector3(1.55, 0.22, 0.68), "stone_light")
		var a3 := -0.2 + k * 0.48
		var rad := radius - 1.02 - (k % 2) * 0.2
		step.position = Vector3(cos(a3) * rad, 0.60 + k * 1.12, sin(a3) * rad)
		step.rotation.y = -a3
		root.add_child(step)
		var scs := CollisionShape3D.new()
		scs.shape = Stage4Props.box_shape(Vector3(1.55, 0.22, 0.68))
		scs.position = step.position
		scs.rotation.y = step.rotation.y
		body.add_child(scs)

	var cap := Stage4Props.cyl(radius - 0.55, 0.28, "stone_light", -1, 12)
	cap.position = Vector3(0, height + 0.14, 0)
	root.add_child(cap)
	var cap_cs := CollisionShape3D.new()
	cap_cs.shape = Stage4Props.cyl_shape(radius - 0.55, 0.28)
	cap_cs.position = cap.position
	body.add_child(cap_cs)
	root.add_child(body)
	add_landmark(root)


func _build_relay() -> void:
	var root := Node3D.new()
	root.name = "PostWarSecurityRelay"
	place(root, RELAY.x, RELAY.y, 0.05)
	root.rotation.y = 0.8
	var tent := Stage4Props.prism(Vector3(3.8, 1.9, 3.0), "canvas_axis")
	root.add_child(tent)
	var flap := Stage4Props.box(Vector3(1.1, 1.1, 0.06), "canvas_green")
	flap.position = Vector3(0, 0.55, 1.52)
	root.add_child(flap)

	var mast := Node3D.new()
	mast.position = Vector3(4.0, 0, 0.5)
	for i in 4:
		var seg := Stage4Props.box(Vector3(0.09, 2.2, 0.09), "iron")
		seg.position = Vector3(0, 1.1 + i * 2.2, 0)
		mast.add_child(seg)
		for s in [-1.0, 1.0]:
			var brace := Stage4Props.box(Vector3(0.05, 2.4, 0.05), "iron")
			brace.position = Vector3(s * 0.16, 1.1 + i * 2.2, 0)
			brace.rotation.z = s * 0.10
			mast.add_child(brace)
	for i in 3:
		var dipol := Stage4Props.box(Vector3(2.4, 0.05, 0.05), "iron")
		dipol.position = Vector3(0, 4.5 + i * 2.6, 0)
		mast.add_child(dipol)
	root.add_child(mast)

	var eq := Stage4Props.box(Vector3(0.78, 0.58, 0.48), "iron")
	eq.position = Vector3(-1.6, 0.29, 0.6)
	root.add_child(eq)
	for i in 3:
		var crate := Stage4Props.box(Vector3(0.64, 0.48, 0.48), "wood_dark")
		crate.position = Vector3(-0.8 + i * 0.75, 0.24, -1.7)
		root.add_child(crate)
	add_landmark(root)

	var clue := ClueNoteStage4.new()
	clue.clue_id = "clue_cipher_logbook"
	clue.title = "Šifrantski dnevnik"
	clue.body = "„Frequenz 4210. Javljanje u 06:00 i 18:00. Punkt Raskršće traži municiju za mitraljez. Kamion kreće u petak.“"
	place(clue, RELAY.x - 1.6, RELAY.y + 0.6, 0.0)
	clue.position.y += 0.58
	add_landmark(clue)

	var med := PickupStage4.new()
	med.visual = "medkit"
	med.heal_amount = 40.0
	med.one_shot = false
	place(med, RELAY.x + 1.8, RELAY.y - 1.6, 0.0)
	add_actor(med)
	var ammo := PickupStage4.new()
	ammo.visual = "ammo"
	ammo.ammo_amount = 20
	ammo.one_shot = false
	place(ammo, RELAY.x + 2.6, RELAY.y - 1.2, 0.0)
	add_actor(ammo)


func _build_alpine_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1200
	for i in 30:
		var x := rng.randf_range(170.0, 640.0)
		var z := rng.randf_range(130.0, 630.0)
		if Vector2(x, z).distance_to(KATUN) < 10.0 or Vector2(x, z).distance_to(KULA) < 12.0:
			continue
		var b := Stage4Props.sphere(rng.randf_range(0.4, 1.7), "stone_light" if i % 2 == 0 else "stone", false, 7)
		place(b, x, z, 0.3)
		b.scale = Vector3(rng.randf_range(1.0, 1.5), rng.randf_range(0.4, 0.9), rng.randf_range(1.0, 1.5))
		b.rotation.y = rng.randf() * TAU
		add_detail(b)


func _build_actors() -> void:
	var vuk := TalkPointStage4.new()
	vuk.speaker_name = "Vuk"
	vuk.speaker_role = "Pastir sa katuna"
	vuk.style = "shepherd"
	vuk.lines = [
		"Ovce znaju kad dolazi nevrijeme. Ljudi ne znaju ništa dok ne zagrmi.",
		"Vidim cijelu dolinu odavde. Vidim i kako Nemci nose antenu gore — svaki dan više žice.",
		"Kula? Stara kula. Zidovi pamte više nego mi. Popni se, ali pazi na stepenice.",
		"Radio stanica je na južnoj strani. Pucaj u antenu, ne u ljude.",
	]
	place(vuk, KATUN.x - 2.6, KATUN.y + 4.0, 0.0)
	add_actor(vuk)
