extends WorldRegion
## Region 4 — Borova šuma i pećina (Durmitor forest hideout).
## The Stage 3.2 MontenegroVegetation already carpets the forest zones; Stage 4
## adds the recessed karst cave hideout, its interior (campfire, map table,
## weapon rack, radio, caches), the ambushed supply cart clearing and the cast.

const CAVE := Vector2(-285.0, -395.0)
const CLEARING := Vector2(-238.0, -330.0)


func build() -> void:
	region_id = "Durmitor_Forest_Hideout"
	focus_point = Vector2(-260.0, -360.0)
	_build_cave_shell()
	_build_cave_interior()
	_build_clearing()
	_build_actors()


func _build_cave_shell() -> void:
	var root := Node3D.new()
	root.name = "Pecina"
	place(root, CAVE.x, CAVE.y, 0.2)
	root.rotation.y = 0.42

	# karst cliff arch
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	for i in 7:
		var rock := Stage4Props.sphere(rng.randf_range(1.9, 3.1), "stone_dark", false, 7)
		var ang := -1.2 + i * 0.42
		rock.position = Vector3(cos(ang) * 9.5, 1.2 + rng.randf() * 3.2, sin(ang) * 9.5 - 3.0)
		rock.scale = Vector3(rng.randf_range(1.0, 1.3), rng.randf_range(0.85, 1.15), rng.randf_range(1.0, 1.3))
		root.add_child(rock)
	var slab := Stage4Props.box(Vector3(11.0, 1.35, 7.5), "stone_dark")
	slab.position = Vector3(0, 5.55, -4.0)
	slab.rotation.x = -0.12
	root.add_child(slab)
	var slab2 := Stage4Props.box(Vector3(7.0, 1.05, 5.0), "stone")
	slab2.position = Vector3(-1.5, 6.85, -2.4)
	slab2.rotation.z = 0.10
	root.add_child(slab2)

	# recessed chamber
	var floor_slab := Stage4Props.box(Vector3(11.0, 0.24, 13.0), "stone_dark")
	floor_slab.position = Vector3(0, 0.12, 1.0)
	root.add_child(floor_slab)
	for s in [-1.0, 1.0]:
		var wall := Stage4Props.box(Vector3(0.9, 4.5, 13.0), "stone_dark")
		wall.position = Vector3(s * 5.5, 2.25, 1.0)
		root.add_child(wall)
	var back := Stage4Props.box(Vector3(11.2, 4.7, 1.0), "stone_dark")
	back.position = Vector3(0, 2.35, 7.3)
	root.add_child(back)

	# timber portal frame
	for s in [-1.0, 1.0]:
		var post := Stage4Props.box(Vector3(0.34, 4.35, 0.34), "wood_dark")
		post.position = Vector3(s * 3.2, 2.18, -3.6)
		root.add_child(post)
	var lintel := Stage4Props.box(Vector3(7.4, 0.40, 0.44), "wood_dark")
	lintel.position = Vector3(0, 4.28, -3.6)
	root.add_child(lintel)
	for s2 in [-1.0, 1.0]:
		var brace := Stage4Props.box(Vector3(0.30, 1.55, 0.30), "wood")
		brace.position = Vector3(s2 * 2.6, 3.85, -3.6)
		brace.rotation.z = -s2 * 0.7
		root.add_child(brace)

	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.60, 0.28)
	glow.light_energy = 1.6
	glow.omni_range = 11.0
	glow.position = Vector3(0, 1.2, 0.5)
	root.add_child(glow)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for entry in [
		[Vector3(11.0, 0.3, 13.0), Vector3(0, 0.15, 1.0)],
		[Vector3(0.9, 4.5, 13.0), Vector3(5.5, 2.25, 1.0)],
		[Vector3(0.9, 4.5, 13.0), Vector3(-5.5, 2.25, 1.0)],
		[Vector3(11.2, 4.9, 1.0), Vector3(0, 2.45, 7.3)],
		[Vector3(11.0, 1.35, 7.5), Vector3(0, 5.55, -4.0)],
	]:
		var cs := CollisionShape3D.new()
		cs.shape = Stage4Props.box_shape(entry[0])
		cs.position = entry[1]
		body.add_child(cs)
	root.add_child(body)

	add_landmark(root)


func _build_cave_interior() -> void:
	var root := Node3D.new()
	root.name = "CaveInterior"
	place(root, CAVE.x, CAVE.y, 0.2)
	root.rotation.y = 0.42

	# campfire
	var fire := Node3D.new()
	fire.position = Vector3(-2.0, 0.2, 0.6)
	var logs := Stage4Props.cyl(0.12, 1.0, "wood_dark", -1, 6)
	logs.rotation.z = PI * 0.5
	logs.position = Vector3(0, 0.12, 0)
	fire.add_child(logs)
	var log2 := Stage4Props.cyl(0.12, 1.0, "wood_dark", -1, 6)
	log2.rotation.z = PI * 0.5
	log2.rotation.y = 1.1
	log2.position = Vector3(0, 0.12, 0)
	fire.add_child(log2)
	var flame := Stage4Props.sphere(0.30, "emissive_amber", false, 7)
	flame.position = Vector3(0, 0.42, 0)
	flame.scale = Vector3(0.8, 1.4, 0.8)
	fire.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.22)
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 0.8, 0)
	fire.add_child(light)
	var flicker := Timer.new()
	flicker.wait_time = 0.12
	flicker.autostart = true
	flicker.timeout.connect(func():
		light.light_energy = randf_range(1.6, 2.4)
		flame.scale = Vector3(0.8, randf_range(1.2, 1.6), 0.8))
	fire.add_child(flicker)
	root.add_child(fire)

	# map table (Luka's command post)
	var table := Node3D.new()
	table.position = Vector3(1.2, 0.2, 2.4)
	var top := Stage4Props.box(Vector3(2.1, 0.10, 1.25), "wood")
	top.position = Vector3(0, 0.79, 0)
	table.add_child(top)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := Stage4Props.box(Vector3(0.10, 0.77, 0.10), "wood_dark")
			leg.position = Vector3(sx * 0.92, 0.385, sz * 0.50)
			table.add_child(leg)
	var sheet := Stage4Props.box(Vector3(1.45, 0.015, 0.95), "cloth_white")
	sheet.position = Vector3(-0.1, 0.85, 0)
	table.add_child(sheet)
	for i in 3:
		var pin := Stage4Props.cyl(0.014, 0.10, "cloth_red", -1, 5)
		pin.position = Vector3(0.25 + i * 0.12, 0.90, -0.10 + i * 0.08)
		table.add_child(pin)
	var lantern := Stage4Props.cyl(0.08, 0.18, "iron_rust", 0.06, 8)
	lantern.position = Vector3(0.82, 0.98, 0.34)
	table.add_child(lantern)
	var l_light := OmniLight3D.new()
	l_light.light_color = Color(1.0, 0.82, 0.50)
	l_light.light_energy = 0.85
	l_light.omni_range = 4.0
	l_light.position = Vector3(0.82, 1.10, 0.34)
	table.add_child(l_light)
	root.add_child(table)

	# weapon rack
	var rack := Node3D.new()
	rack.position = Vector3(-3.6, 0.2, 3.6)
	var rback := Stage4Props.box(Vector3(1.65, 1.15, 0.14), "wood_dark")
	rback.position = Vector3(0, 1.38, 0)
	rack.add_child(rback)
	for i in 3:
		var rifle := Stage4Props.box(Vector3(0.07, 0.10, 1.05), "wood_dark")
		rifle.position = Vector3(-0.48 + i * 0.48, 0.95, 0.12)
		rack.add_child(rifle)
	root.add_child(rack)

	var med := PickupStage4.new()
	med.visual = "medkit"
	med.heal_amount = 50.0
	med.one_shot = false
	med.position = Vector3(3.6, 0.2, 4.8)
	root.add_child(med)
	var ammo := PickupStage4.new()
	ammo.visual = "ammo"
	ammo.ammo_amount = 25
	ammo.one_shot = false
	ammo.position = Vector3(-1.0, 0.2, 5.2)
	root.add_child(ammo)
	var band := PickupStage4.new()
	band.visual = "bandage"
	band.heal_amount = 20.0
	band.one_shot = false
	band.position = Vector3(3.2, 0.2, 5.6)
	root.add_child(band)

	# radio set
	var radio := Node3D.new()
	radio.position = Vector3(4.0, 0.2, 1.0)
	var rcrate := Stage4Props.box(Vector3(0.70, 0.50, 0.50), "wood_dark")
	rcrate.position = Vector3(0, 0.25, 0)
	radio.add_child(rcrate)
	var rbox := Stage4Props.box(Vector3(0.50, 0.34, 0.28), "iron")
	rbox.position = Vector3(0, 0.67, 0)
	radio.add_child(rbox)
	var ant := Stage4Props.cyl(0.01, 1.4, "iron", 0.008, 4)
	ant.position = Vector3(-0.18, 1.30, 0)
	radio.add_child(ant)
	root.add_child(radio)

	for i in 2:
		var mat := Stage4Props.box(Vector3(0.90, 0.10, 1.95), "hay")
		mat.position = Vector3(-4.2, 0.28, -3.0 + i * 2.2)
		mat.rotation.y = 0.1
		root.add_child(mat)
	for i in 3:
		var crate := Stage4Props.box(Vector3(0.64, 0.48, 0.48), "wood_dark")
		crate.position = Vector3(-3.8 + i * 0.40, 0.44 + (i / 2) * 0.48, -1.0)
		root.add_child(crate)

	var clue := ClueNoteStage4.new()
	clue.clue_id = "clue_partisan_orders"
	clue.title = "Partizanske radio-naredbe"
	clue.body = "„Druže Komandante, javljamo: kamion municije kreće u petak u 14:00 iz Bijelog Polja. Snage: 12 vojnika, jedan oficir. Predlažemo zasjedu na prevoju. Odobrenje — Zeta.“"
	clue.position = Vector3(1.3, 1.05, 2.4)
	root.add_child(clue)

	add_landmark(root)


func _build_clearing() -> void:
	var root := Node3D.new()
	root.name = "AmbushedSupplyCart"
	place(root, CLEARING.x, CLEARING.y, 0.05)
	root.rotation.y = 1.2
	var cart := Node3D.new()
	cart.rotation.z = 1.35
	cart.position = Vector3(0, 0.45, 0)
	var bed := Stage4Props.box(Vector3(2.4, 0.13, 1.2), "wood")
	cart.add_child(bed)
	for s in [-1.0, 1.0]:
		var side := Stage4Props.box(Vector3(2.4, 0.40, 0.07), "wood_dark")
		side.position = Vector3(0, 0.21, s * 0.60)
		cart.add_child(side)
	for wx in [-0.8, 0.8]:
		var wheel := Stage4Props.cyl(0.42, 0.10, "wood_dark", -1, 10)
		wheel.rotation.z = PI * 0.5
		wheel.position = Vector3(wx, 0.42, 0.72)
		cart.add_child(wheel)
	root.add_child(cart)

	var rng := RandomNumberGenerator.new()
	rng.seed = 6611
	for i in 6:
		var crate := Stage4Props.box(Vector3(0.55, 0.40, 0.45), "wood_dark")
		crate.position = Vector3(rng.randf_range(-3.5, 3.5), 0.22, rng.randf_range(-3.0, 3.0))
		crate.rotation.y = rng.randf() * TAU
		root.add_child(crate)
	var patch := Stage4Props.plate(Vector2(5.0, 4.0), "gravel")
	patch.position = Vector3(0, 0.06, 0)
	root.add_child(patch)
	add_landmark(root)

	var ammo := PickupStage4.new()
	ammo.visual = "ammo"
	ammo.ammo_amount = 20
	ammo.one_shot = false
	place(ammo, CLEARING.x + 2.4, CLEARING.y + 1.2, 0.0)
	add_actor(ammo)


func _build_actors() -> void:
	var luka := TalkPointStage4.new()
	luka.speaker_name = "Komandant Luka"
	luka.speaker_role = "Partizanski komandir"
	luka.style = "partisan"
	luka.lines = [
		"Dobro došao, Vlado. Sjedi za sto — mapa ne laže, ljudi lažu.",
		"Punkt kod raskršća drži šest vojnika. Naredbe su u kasi kasarne. Donesi ih, i znaćemo kada kamion kreće.",
		"Ako možeš — ne diraj stražu na mostu. Samo papiri. Tišina je pola posla.",
		"Poslije toga, čeka nas radio na Crnom vrhu. Ako ga ne uništimo, svaki naš pokret je na njihovoj mapi.",
	]
	place(luka, CAVE.x + 0.3, CAVE.y + 1.2, 0.0)
	luka.position.y += 0.35
	add_actor(luka)

	var nikola := TalkPointStage4.new()
	nikola.speaker_name = "Stražar Nikola"
	nikola.speaker_role = "Osmatrač na litici"
	nikola.style = "partisan"
	nikola.lines = [
		"Psss! Ovdje se ne viče. Vidim drum do Bijelog Polja — dvije kolone danas.",
		"Kamion je prošao u podne. Vratio se prazan. Znači, municija je kod punkta.",
	]
	place(nikola, CAVE.x - 8.0, CAVE.y - 6.0, 0.0)
	add_actor(nikola)
