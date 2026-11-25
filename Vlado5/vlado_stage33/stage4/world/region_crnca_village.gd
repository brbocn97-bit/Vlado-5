extends WorldRegion
## Region 2 — Selo Gornja Crnča (western terraced plateau).
## Chapel with bell gable, enterable kafana and elder's stone house, čardak with
## balcony, timber barn, stone fountain, cart and haystacks, plus Petar & Milica.

const CHAPEL := Vector2(-395.0, 34.0)
const KAFANA := Vector2(-302.0, -6.0)
const ELDER := Vector2(-372.0, 12.0)
const CARDACK := Vector2(-345.0, 60.0)


func build() -> void:
	region_id = "Crnca_Village"
	focus_point = Vector2(-345.0, 20.0)
	_build_chapel()
	_build_kafana()
	_build_elder_house()
	_build_cardak()
	_build_barn_fountain_cart()
	_build_street()
	_build_actors()


func _build_chapel() -> void:
	var root := Node3D.new()
	root.name = "StoneChapel"
	place(root, CHAPEL.x, CHAPEL.y, 0.05)
	root.rotation.y = 0.32

	var body := Stage4Props.box(Vector3(5.0, 3.3, 7.0), "stone_light")
	body.position = Vector3(0, 1.65, 0)
	root.add_child(body)
	var apse := Stage4Props.cyl(1.65, 3.1, "stone_light", 1.65, 12)
	apse.position = Vector3(0, 1.55, -4.1)
	root.add_child(apse)
	var roof := Stage4Props.gable(5.0, 7.0, 1.85, 0.45, "slate")
	roof.position = Vector3(0, 3.3, 0)
	roof.rotation.y = PI * 0.5
	root.add_child(roof)
	# bell gable
	var gable := Stage4Props.box(Vector3(1.5, 1.7, 0.42), "stone_light")
	gable.position = Vector3(0, 5.15, 3.3)
	root.add_child(gable)
	var opening := Stage4Props.box(Vector3(0.62, 0.85, 0.46), "dark_hole")
	opening.position = Vector3(0, 5.15, 3.3)
	root.add_child(opening)
	var bell := Stage4Props.sphere(0.20, "iron_rust", true, 8)
	bell.position = Vector3(0, 5.0, 3.3)
	root.add_child(bell)
	var cap := Stage4Props.prism(Vector3(1.9, 0.8, 0.9), "slate")
	cap.position = Vector3(0, 6.0, 3.3)
	cap.rotation.y = PI * 0.5
	root.add_child(cap)
	var door := Stage4Props.box(Vector3(1.0, 2.0, 0.12), "wood_dark")
	door.position = Vector3(0, 1.0, 3.52)
	root.add_child(door)
	for s in [-1.0, 1.0]:
		var cv := Stage4Props.box(Vector3(0.10, 0.9, 0.08), "iron")
		cv.position = Vector3(0, 4.3, 3.52)
		root.add_child(cv)
	var ch := Stage4Props.box(Vector3(0.50, 0.10, 0.08), "iron")
	ch.position = Vector3(0, 4.50, 3.52)
	root.add_child(ch)
	for s2 in [-1.0, 1.0]:
		for i in 2:
			var win := Stage4Props.box(Vector3(0.34, 0.72, 0.12), "dark_hole")
			win.position = Vector3(s2 * 2.52, 2.1, -1.6 + i * 2.4)
			root.add_child(win)

	var body_col := StaticBody3D.new()
	body_col.collision_layer = 1
	body_col.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = Stage4Props.box_shape(Vector3(5.0, 3.3, 7.0))
	cs.position = Vector3(0, 1.65, 0)
	body_col.add_child(cs)
	root.add_child(body_col)
	add_landmark(root)

	# graveyard crosses
	var rng := RandomNumberGenerator.new()
	rng.seed = 3001
	for i in 9:
		var gx := CHAPEL.x - 6.0 + rng.randf_range(-4.0, 4.0)
		var gz := CHAPEL.y + 7.5 + rng.randf_range(0.0, 5.0)
		var grave := Node3D.new()
		place(grave, gx, gz, 0.0)
		var pole := Stage4Props.box(Vector3(0.07, 0.85, 0.07), "iron_rust")
		pole.position = Vector3(0, 0.42, 0)
		grave.add_child(pole)
		var arm := Stage4Props.box(Vector3(0.34, 0.07, 0.07), "iron_rust")
		arm.position = Vector3(0, 0.62, 0)
		grave.add_child(arm)
		grave.rotation.z = rng.randf_range(-0.07, 0.07)
		add_detail(grave)


func _build_kafana() -> void:
	var house := Stage4Buildings.make_house_glb("zgrade/kuca_kamena.glb", "Kafana")
	if house.is_empty():
		house = Stage4Buildings.make_house({
		"width": 8.6, "depth": 6.4, "wall_height": 3.05, "roof_rise": 1.85,
		"wall_mat": "plaster_warm", "roof_mat": "slate", "door_side": 0,
		"windows": true, "plaster_upper": true, "chimney": true, "name": "Kafana",
	})
	place(house["root"], KAFANA.x, KAFANA.y, 0.05)
	house["root"].rotation.y = -0.22
	add_landmark(house["root"])
	Stage4Buildings.furnish(house, "kafana", [{
		"id": "clue_kafana_ledger",
		"title": "Kafanska knjiga",
		"body": "FIKCIJA MISIJE: „Nova patrola dolazi kroz selo i provjerava kuće. Sumnjivi tragovi vode prema borovoj šumi i starom mostu.“ Ovo nije istorijski citat.",
	}])

	# terrace awning + three outdoor tables
	var awning := Stage4Props.plate(Vector2(6.4, 3.0), "canvas")
	awning.position = Vector3(0, 2.70, 4.4)
	awning.rotation.x = -0.16
	house["root"].add_child(awning)
	for s in [-1.0, 1.0]:
		var ap := Stage4Props.cyl(0.06, 2.6, "wood_dark", -1, 6)
		ap.position = Vector3(s * 3.1, 1.3, 5.8)
		house["root"].add_child(ap)
	for i in 3:
		var t := Node3D.new()
		t.position = Vector3(-2.2 + i * 2.2, 0.0, 4.6)
		var top := Stage4Props.cyl(0.46, 0.07, "wood", -1, 10)
		top.position = Vector3(0, 0.73, 0)
		t.add_child(top)
		var leg := Stage4Props.cyl(0.06, 0.71, "wood_dark", -1, 6)
		leg.position = Vector3(0, 0.355, 0)
		t.add_child(leg)
		house["root"].add_child(t)

	# medkit crate by the side door
	var med := PickupStage4.new()
	med.visual = "medkit"
	med.heal_amount = 35.0
	med.one_shot = false
	place(med, KAFANA.x + 5.4, KAFANA.y + 3.0, 0.0)
	add_actor(med)


func _build_elder_house() -> void:
	var house := Stage4Buildings.make_house_glb("zgrade/kuca_kamena.glb", "ElderStoneHouse")
	if house.is_empty():
		house = Stage4Buildings.make_house({
		"width": 6.6, "depth": 5.4, "wall_height": 2.85, "roof_rise": 1.85,
		"wall_mat": "stone", "roof_mat": "slate", "door_side": 2,
		"windows": true, "chimney": true, "name": "ElderStoneHouse",
	})
	place(house["root"], ELDER.x, ELDER.y, 0.05)
	house["root"].rotation.y = 0.9
	add_landmark(house["root"])
	Stage4Buildings.furnish(house, "home", [{
		"id": "clue_elder_map",
		"title": "Petarova skica straža",
		"body": "Na hartiji ugljem: prevoj kod raskršća. Tri crvene crte — stražar na rampi, osmatrač na tornju, mitraljez u bunkeru. Ispod: „Smjena u zoru. Kamion dolazi sa istoka u šest.“",
	}])
	for i in 5:
		var log := Stage4Props.cyl(0.11, 1.4, "wood_dark", -1, 6)
		place(log, ELDER.x - 4.0 + i * 0.24, ELDER.y + 2.4, 0.0)
		log.rotation.z = PI * 0.5
		log.position.y += 0.35
		add_detail(log)


func _build_cardak() -> void:
	var house := Stage4Buildings.make_house_glb("zgrade/kuca_brvnara.glb", "CardakHouse")
	if house.is_empty():
		house = Stage4Buildings.make_house({
		"width": 6.0, "depth": 5.0, "wall_height": 2.80, "roof_rise": 1.70,
		"wall_mat": "plaster", "roof_mat": "slate", "door_side": 0,
		"windows": true, "plaster_upper": true, "chimney": false, "name": "CardakHouse",
	})
	place(house["root"], CARDACK.x, CARDACK.y, 0.05)
	house["root"].rotation.y = 2.6
	add_landmark(house["root"])
	# wooden balcony (ganjak)
	var root: Node3D = house["root"]
	var deck := Stage4Props.box(Vector3(5.4, 0.12, 1.5), "wood")
	deck.position = Vector3(0, 2.55, 3.2)
	root.add_child(deck)
	for s in [-1.0, 1.0]:
		var col := Stage4Props.box(Vector3(0.12, 2.55, 0.12), "wood_dark")
		col.position = Vector3(s * 2.4, 1.27, 3.85)
		root.add_child(col)
	var railing := Stage4Props.box(Vector3(5.4, 0.09, 0.08), "wood_dark")
	railing.position = Vector3(0, 3.35, 3.95)
	root.add_child(railing)
	for i in 7:
		var bal := Stage4Props.box(Vector3(0.06, 0.75, 0.06), "wood")
		bal.position = Vector3(-2.5 + i * 0.83, 2.98, 3.95)
		root.add_child(bal)


func _build_barn_fountain_cart() -> void:
	# timber barn
	var barn := Node3D.new()
	barn.name = "TimberBarn"
	place(barn, -330.0, -30.0, 0.1)
	barn.rotation.y = 0.5
	var body := Stage4Props.box(Vector3(6.0, 2.9, 4.4), "wood_dark")
	body.position = Vector3(0, 1.45, 0)
	barn.add_child(body)
	for i in 5:
		var beam := Stage4Props.box(Vector3(6.02, 0.13, 4.42), "wood")
		beam.position = Vector3(0, 0.28 + i * 0.61, 0)
		barn.add_child(beam)
	var roof := Stage4Props.gable(6.0, 4.4, 1.6, 0.4, "slate")
	roof.position = Vector3(0, 2.9, 0)
	roof.rotation.y = PI * 0.5
	barn.add_child(roof)
	add_landmark(barn)

	# stone fountain (česma)
	var fountain := Node3D.new()
	fountain.name = "StoneFountain"
	place(fountain, -352.0, 24.0, 0.0)
	var trough := Stage4Props.box(Vector3(2.2, 0.60, 0.9), "stone_light")
	trough.position = Vector3(0, 0.30, 0)
	fountain.add_child(trough)
	var water := Stage4Props.box(Vector3(2.0, 0.05, 0.7), "glass")
	water.position = Vector3(0, 0.57, 0)
	fountain.add_child(water)
	var pillar := Stage4Props.box(Vector3(0.42, 1.5, 0.36), "stone")
	pillar.position = Vector3(0, 0.95, -0.55)
	fountain.add_child(pillar)
	var spout := Stage4Props.cyl(0.05, 0.34, "iron_rust", -1, 6)
	spout.rotation.x = PI * 0.5
	spout.position = Vector3(0, 1.05, -0.30)
	fountain.add_child(spout)
	add_landmark(fountain)

	# hay cart
	var cart := Node3D.new()
	place(cart, -360.0, -18.0, 0.0)
	cart.rotation.y = -0.6
	var bed := Stage4Props.box(Vector3(2.6, 0.14, 1.3), "wood")
	bed.position = Vector3(0, 0.75, 0)
	cart.add_child(bed)
	for s in [-1.0, 1.0]:
		var side := Stage4Props.box(Vector3(2.6, 0.42, 0.08), "wood_dark")
		side.position = Vector3(0, 0.96, s * 0.63)
		cart.add_child(side)
		for wx in [-0.85, 0.85]:
			var wheel := Stage4Props.cyl(0.44, 0.10, "wood_dark", -1, 12)
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(wx, 0.44, s * 0.78)
			cart.add_child(wheel)
	var load := Stage4Props.sphere(0.85, "hay", false, 10)
	load.position = Vector3(-0.2, 1.05, 0)
	load.scale = Vector3(1.5, 0.75, 0.8)
	cart.add_child(load)
	add_detail(cart)

	for i in 3:
		var hs := Stage4Props.sphere(1.0, "hay", false, 10)
		place(hs, -326.0 + i * 2.6, -25.0, 0.15)
		hs.scale = Vector3(1.0, 1.25, 1.0)
		add_detail(hs)


func _build_street() -> void:
	# cobbled ribbon along the village street
	var pts := [Vector2(-455, -10), Vector2(-400, 6), Vector2(-330, 18), Vector2(-250, 30)]
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 6.0)
		for k in n:
			var t := (float(k) + 0.5) / float(n)
			var p := a.lerp(b, t)
			var plate := Stage4Props.plate(Vector2(4.4, 6.9), "cobble")
			place(plate, p.x, p.y, -0.06)
			plate.rotation.y = atan2(b.x - a.x, b.y - a.y)
			add_detail(plate)

	for i in 4:
		var lx := -420.0 + i * 34.0
		var lz := 20.0 + sin(float(i)) * 6.0
		var lamp := Node3D.new()
		place(lamp, lx, lz, 0.0)
		var post := Stage4Props.cyl(0.07, 3.0, "iron", -1, 6)
		post.position = Vector3(0, 1.5, 0)
		lamp.add_child(post)
		var head := Stage4Props.box(Vector3(0.28, 0.34, 0.28), "iron")
		head.position = Vector3(0, 3.05, 0)
		lamp.add_child(head)
		var glow := Stage4Props.box(Vector3(0.19, 0.22, 0.19), "emissive_amber")
		glow.position = Vector3(0, 3.0, 0)
		lamp.add_child(glow)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.78, 0.46)
		light.light_energy = 0.75
		light.omni_range = 6.0
		light.position = Vector3(0, 3.0, 0)
		lamp.add_child(light)
		add_detail(lamp)


func _build_actors() -> void:
	var petar := TalkPointStage4.new()
	petar.speaker_name = "Petar"
	petar.speaker_role = "Seoski starješina"
	petar.style = "elder"
	petar.lines = [
		"Sjedi, dijete. Znam zašto si došao. Punkt na raskršću — šest ljudi, možda sedam.",
		"Rampa se spušta u šest ujutro. Kamion iz Bijelog Polja dolazi istočnim drumom.",
		"Tvoj otac je bio dobar čovjek. On bi ti rekao: ne juri u smrt. Idi noću, preko gaza na jugu.",
		"Ako doneseš njihove papire, selo će znati da nismo sami. Idi sa Bogom, Vlado.",
	]
	place(petar, CHAPEL.x + 1.5, CHAPEL.y + 5.2, 0.0)
	add_actor(petar)

	var milica := TalkPointStage4.new()
	milica.speaker_name = "Milica"
	milica.speaker_role = "Kafedžika"
	milica.style = "villager"
	milica.lines = [
		"Aj, Vlado, uđi. Kafa je vruća, a vijesti su hladne.",
		"Oficiri su pili ovdje. Ostavili su knjigu sa narudžbama na stolu — pročitaj ako smiješ.",
		"Ako pucaš po drumu, pucaj dalje od sela. Đeca spavaju na spratu.",
		"Uzmi zavoje iz sanduka iza vrata. Ne pitaj odakle su.",
	]
	place(milica, KAFANA.x + 1.2, KAFANA.y - 3.4, 0.0)
	add_actor(milica)
