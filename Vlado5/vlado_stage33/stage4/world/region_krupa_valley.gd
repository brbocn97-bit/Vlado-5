extends WorldRegion
const Stage4TerenProps := preload("res://stage4/props/stage4_teren_props.gd")
## Region 1 — Dolina Krupe.
## Stage 4 additions on top of the Stage 3.2 village: an enterable homestead
## (Vlado's kuća) with hearth and clue, Marko the scout by the well, the six
## shooting-range targets already exist in Stage 3.2 (left untouched), plus
## dry-stone detail and the river meadow props.

const HOMESTEAD := Vector2(-46.0, 20.0)


func build() -> void:
	region_id = "Krupa_Valley"
	focus_point = Vector2(-46.0, 20.0)
	_build_homestead()
	_build_bridge_lanterns()
	_build_meadow_detail()
	_build_actors()


func _build_homestead() -> void:
	# pravi GLB model; ako ga nema, proceduralna verzija
	var house := Stage4Buildings.make_house_glb("zgrade/kuca_kamena.glb", "MainStoneHouse_Stage4")
	if house.is_empty():
		house = Stage4Buildings.make_house({
			"width": 7.4, "depth": 5.8, "wall_height": 2.95, "roof_rise": 1.95,
			"wall_mat": "stone", "roof_mat": "slate", "door_side": 0,
			"windows": true, "plaster_upper": false, "chimney": true,
			"name": "MainStoneHouse_Stage4",
		})
	place(house["root"], HOMESTEAD.x, HOMESTEAD.y, 0.05)
	house["root"].rotation.y = 0.16
	add_landmark(house["root"])

	Stage4Buildings.furnish(house, "home", [{
		"id": "clue_homestead_letter",
		"title": "Očeva posljednja poruka",
		"body": "„Vlado, ako ovo čitaš — puška je u sanduku pod prozorom. Čuvaj Marka i ne idi sam preko mosta. Nemci su postavili punkt kod raskršća, a naš narod šuti. — Otac“",
	}])

	# porch bench + rain barrel
	var bench := Stage4Props.box(Vector3(1.7, 0.10, 0.42), "wood")
	place(bench, HOMESTEAD.x + 1.6, HOMESTEAD.y + 3.6, 0.52)
	add_detail(bench)
	var barrel := Stage4Props.cyl(0.36, 0.90, "wood", -1, 10)
	place(barrel, HOMESTEAD.x + 5.0, HOMESTEAD.y + 3.0, 0.05)
	barrel.position.y += 0.45
	add_detail(barrel)

	# woodcutter's cottage (enterable)
	var cottage := Stage4Buildings.make_house_glb("zgrade/kuca_brvnara.glb", "Cottage_Stage4")
	if cottage.is_empty():
		cottage = Stage4Buildings.make_house({
			"width": 5.2, "depth": 4.4, "wall_height": 2.65, "roof_rise": 1.55,
			"wall_mat": "plaster_warm", "roof_mat": "slate", "door_side": 2,
			"windows": true, "chimney": true, "name": "Cottage_Stage4",
		})
	place(cottage["root"], HOMESTEAD.x - 24.0, HOMESTEAD.y - 9.0, 0.05)
	cottage["root"].rotation.y = -0.35
	add_landmark(cottage["root"])
	Stage4Buildings.furnish(cottage, "home")

	# small barn with hay
	var barn := Stage4Props.box(Vector3(6.0, 2.9, 4.4), "wood_dark")
	place(barn, HOMESTEAD.x - 13.0, HOMESTEAD.y + 10.0, 0.1)
	barn.position.y += 1.45
	add_landmark(barn)
	for i in 3:
		var hay := Stage4Props.sphere(0.95, "hay", false, 10)
		place(hay, HOMESTEAD.x - 8.0 + i * 2.4, HOMESTEAD.y + 12.0, 0.1)
		hay.scale = Vector3(1.0, 0.85, 1.0)
		add_detail(hay)

	# dry-stone perimeter (međe)
	_dry_wall(Vector2(HOMESTEAD.x - 22, HOMESTEAD.y + 14), Vector2(HOMESTEAD.x + 22, HOMESTEAD.y + 14))
	_dry_wall(Vector2(HOMESTEAD.x - 22, HOMESTEAD.y - 6), Vector2(HOMESTEAD.x - 22, HOMESTEAD.y + 14))


func _dry_wall(a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	var segs := maxi(2, int(length / 1.2))
	var yaw := atan2(b.y - a.y, b.x - a.x)
	for i in segs:
		var t := (float(i) + 0.5) / float(segs)
		var p := a.lerp(b, t)
		var stone := Stage4Props.box(Vector3(1.12, 0.54, 0.48), "stone" if i % 2 == 0 else "stone_dark")
		place(stone, p.x, p.y, 0.16)
		stone.position.y += 0.27
		stone.rotation.y = -yaw
		add_detail(stone)


func _build_bridge_lanterns() -> void:
	# two iron lanterns framing the Stage 3.2 bridge (which stays untouched)
	for s in [-1.0, 1.0]:
		var post := Stage4Props.cyl(0.06, 2.1, "iron", 0.05, 6)
		var x: float = 23.53 + float(s) * 5.2
		var z: float = -16.0 + float(s) * 2.2
		place(post, x, z, 0.0)
		post.position.y += 1.05
		add_detail(post)
		var lamp := Stage4Props.box(Vector3(0.20, 0.26, 0.20), "emissive_amber")
		lamp.position = post.position + Vector3(0, 1.2, 0)
		add_detail(lamp)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.76, 0.44)
		light.light_energy = 0.85
		light.omni_range = 5.5
		light.omni_attenuation = 1.5
		light.position = lamp.position
		add_detail(light)


func _build_meadow_detail() -> void:
	# riverbank boulders + reeds, kept clear of the road and the village terrace
	var rng := RandomNumberGenerator.new()
	rng.seed = 7712
	# === PRAVE GLB STIJENE umjesto bijelih sfera (defekt #2) ===
	var rock_models := ["stijena_kosa.glb", "stijena_plitka.glb",
			"stijene_razbijene.glb", "litica.glb"]
	var rock_sizes := {}
	for rm in rock_models:
		if ResourceLoader.exists("res://assets/models/teren/" + rm):
			# normalizuj na 0.9-2.6 m da izgleda kao kamen, ne kao planina
			rock_sizes[rm] = Stage4TerenProps.size_for(rm, 1.6)
	if rock_sizes.is_empty():
		# fallback na stare sfere ako GLB nema (ne bi trebalo)
		for i in 24:
			var fx := rng.randf_range(-150.0, 150.0)
			var fz := rng.randf_range(-150.0, 150.0)
			if terrain_data.get_river_distance(fx, fz) < 8.0:
				continue
			var fb := Stage4Props.sphere(rng.randf_range(0.20, 0.45), "stone", false, 7)
			place(fb, fx, fz, 0.28)
			add_detail(fb)
	else:
		var rock_keys: Array = rock_sizes.keys()
		for i in 34:
			var x := rng.randf_range(-155.0, 155.0)
			var z := rng.randf_range(-155.0, 155.0)
			if terrain_data.get_river_distance(x, z) < 7.0:
				continue
			if Vector2(x - (-5.0), z - 9.5).length() < 26.0:
				continue
			if terrain_data.get_slope_deg(x, z) > 38.0:
				continue
			var rk: String = str(rock_keys[rng.randi() % rock_keys.size()])
			var sz: float = float(rock_sizes[rk]) * rng.randf_range(0.55, 1.85)
			# place_one vec dodaje u detroot; ne dodavati ponovo.
			var rm2: Node3D = Stage4TerenProps.place_one(
					detroot, rk, Vector3(x, terrain_data.get_height(x, z) - 0.10 * sz, z),
					rng.randf() * TAU, sz)
			if rm2 == null:
				continue


func _build_actors() -> void:
	var marko := TalkPointStage4.new()
	marko.speaker_name = "Marko"
	marko.speaker_role = "Seoski izviđač"
	marko.style = "villager"
	marko.lines = [
		"Vlado! Dobro da si tu. Nemci su juče prošli drumom — šest vojnika i kamion municije.",
		"Čuo sam da su postavili punkt kod raskršća, istočno preko mosta. Bunker, stražarnica, sve.",
		"Idi do starog Petra u Gornju Crnču — on zna raspored straža. Ja čuvam kuću dok si odsutan.",
		"Pazi na most. Ako pucaš prije vremena, cijelo selo će platiti.",
	]
	place(marko, HOMESTEAD.x + 8.0, HOMESTEAD.y - 3.0, 0.0)
	add_actor(marko)
