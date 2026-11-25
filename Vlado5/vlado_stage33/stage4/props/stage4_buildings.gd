class_name Stage4Buildings
extends RefCounted

# preload umjesto class_name — ne zavisi od .godot kesa (global_script_class_cache)
const Stage4PropsGLB := preload("res://stage4/props/stage4_props_glb.gd")
## Stage4Buildings — enterable structures (hollow walls, real door openings,
## hinged doors, interior furnishing, occluders).
##
## The Stage 3.2 settlement builds SOLID box houses (walls + collider box), so
## they cannot be entered. Stage 4 needs interiors for the six regions, so this
## builder constructs hollow shells that match the baseline's stone/slate/wood
## materials and proportions, and returns the door + interior anchor.

const WALL_T := 0.34

# --------------------------------------------------------------- house shell
## params: width, depth, wall_height, roof_rise, wall_mat, roof_mat, door_side
##         (0=+Z,1=-Z,2=+X,3=-X), windows(bool), plaster_upper(bool),
##         chimney(bool), name(String)
static func make_house(p: Dictionary) -> Dictionary:
	var w: float = p.get("width", 7.0)
	var d: float = p.get("depth", 5.6)
	var h: float = p.get("wall_height", 2.9)
	var rise: float = p.get("roof_rise", 1.85)
	var wall_mat: String = p.get("wall_mat", "stone")
	var roof_mat: String = p.get("roof_mat", "slate")
	var door_side: int = p.get("door_side", 0)
	var windows: bool = p.get("windows", true)
	var plaster_upper: bool = p.get("plaster_upper", false)
	var chimney: bool = p.get("chimney", true)
	var nm: String = p.get("name", "Kuca")

	var root := Node3D.new()
	root.name = nm

	var door_w := 1.10
	var door_h := 2.10
	var win_w := 0.82
	var win_h := 0.92
	var sill := 1.05

	# plinth + floor
	var plinth := box(Vector3(w + 0.38, 0.62, d + 0.38), "stone_dark")
	plinth.position = Vector3(0, -0.18, 0)
	root.add_child(plinth)
	var floor_slab := box(Vector3(w - WALL_T, 0.16, d - WALL_T), "wood_dark")
	floor_slab.position = Vector3(0, 0.12, 0)
	root.add_child(floor_slab)

	# four walls (with door + window holes on the relevant face)
	_wall(root, w, h, Vector3(0, 0, d * 0.5), 0.0, door_side == 0,
		door_w, door_h, windows, win_w, win_h, sill, wall_mat)
	_wall(root, w, h, Vector3(0, 0, -d * 0.5), 0.0, door_side == 1,
		door_w, door_h, windows, win_w, win_h, sill, wall_mat)
	_wall(root, d, h, Vector3(w * 0.5, 0, 0), PI * 0.5, door_side == 2,
		door_w, door_h, windows, win_w, win_h, sill, wall_mat)
	_wall(root, d, h, Vector3(-w * 0.5, 0, 0), PI * 0.5, door_side == 3,
		door_w, door_h, windows, win_w, win_h, sill, wall_mat)

	if plaster_upper:
		var band := box(Vector3(w + 0.10, 0.55, d + 0.10), "plaster")
		band.position = Vector3(0, h - 0.55, 0)
		root.add_child(band)

	# roof + gable infill
	var roof := gable(w, d, rise, 0.55, roof_mat)
	roof.position = Vector3(0, h, 0)
	root.add_child(roof)
	for s in [-1.0, 1.0]:
		var tri := prism(Vector3(d, rise, 0.14), wall_mat)
		tri.position = Vector3(0, h, s * (d * 0.5 - 0.02))
		tri.rotation.y = PI * 0.5
		root.add_child(tri)

	if chimney:
		var ch := box(Vector3(0.62, rise + 1.2, 0.62), "stone")
		ch.position = Vector3(w * 0.24, h + (rise + 1.2) * 0.5 - 0.5, -d * 0.12)
		root.add_child(ch)

	# interactable hinged door in the opening
	var door: HingedDoorStage4 = null
	if door_side >= 0:
		door = HingedDoorStage4.new()
		door.width = door_w
		door.height = door_h
		door.name = "Door"
		match door_side:
			0: door.position = Vector3(0, 0, d * 0.5)
			1: door.position = Vector3(0, 0, -d * 0.5)
			2:
				door.position = Vector3(w * 0.5, 0, 0)
				door.rotation.y = PI * 0.5
			3:
				door.position = Vector3(-w * 0.5, 0, 0)
				door.rotation.y = PI * 0.5
		root.add_child(door)
		# timber frame
		for s in [-1.0, 1.0]:
			var post := box(Vector3(0.13, door_h + 0.14, 0.24), "wood_dark")
			post.position = door.position + (Vector3(s * (door_w * 0.5 + 0.06), (door_h + 0.14) * 0.5, 0)
				if door_side < 2 else Vector3(0, (door_h + 0.14) * 0.5, s * (door_w * 0.5 + 0.06)))
			root.add_child(post)
		var lintel := box(Vector3(door_w + 0.30, 0.15, 0.24), "wood_dark")
		lintel.position = door.position + Vector3(0, door_h + 0.07, 0)
		if door_side >= 2:
			lintel.rotation.y = PI * 0.5
		root.add_child(lintel)

	# wall colliders
	var body := _wall_colliders(w, d, h, door_side, door_w, door_h)
	var fit2 := root.get_node_or_null("AutoFit") as Node3D
	if fit2:
		fit2.add_child(body)
	else:
		root.add_child(body)

	# occlusion box: hides the interior once the wall blocks the view
	var occ := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = Vector3(w - WALL_T * 2.0, h, d - WALL_T * 2.0)
	occ.occluder = bo
	occ.position = Vector3(0, h * 0.5, 0)
	root.add_child(occ)

	var anchor := Node3D.new()
	anchor.name = "InteriorAnchor"
	anchor.position = Vector3(0, 0.24, 0)
	root.add_child(anchor)

	return { "root": root, "door": door, "anchor": anchor, "size": Vector3(w, h + rise, d) }


# ---------------------------------------------------------------- GLB models
## Učitaj pravi GLB model kuće ako postoji, inače vrati null.
## Pozivalac tada nastavlja sa proceduralnom verzijom.
static func make_house_glb(model_rel: String, nm: String = "Kuca") -> Dictionary:
	var scene := Stage4PropsGLB.load_scene(model_rel)
	if scene == null:
		return {}
	var root: Node3D = scene.instantiate()
	if root == null:
		return {}
	root.name = nm

	# nađi gabarite cele kuce
	# BUG (popravljen): `mi.transform` je transform SAMO u odnosu na roditelja.
	# Sketchfab GLB ima 3-4 nivoa (Sketchfab_model > *.fbx > House > mesh),
	# pa se skala i pozicija iz roditelja gubila: kuca je mjerena kao 300 m
	# umjesto 6 m, a zatim su HouseCollision i InteriorAnchor "odletjeli"
	# 145 m od kuce. Sada akumuliramo transforme od root-a nadole.
	var aabb := AABB()
	var found := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var c: Node = item[0]
		var xf: Transform3D = item[1]
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			var b: AABB = xf * mi.mesh.get_aabb()
			aabb = b if not found else aabb.merge(b)
			found = true
		for ch in c.get_children():
			var cxf: Transform3D = xf
			if ch is Node3D:
				cxf = xf * (ch as Node3D).transform
			stack.append([ch, cxf])

	var size := aabb.size if found else Vector3(7.0, 3.0, 6.0)

	# === AUTO-NORMALIZACIJA VELICINE (defekt #6, lebdece zgrade) ===
	# Sketchfab GLB modeli dolaze u proizvoljnim jedinicama. kuca_brvnara je
	# izlazila 519 x 419 x 633 METRA, avion_olupina 850 m — pa su zgrade
	# izgledale kao planine, a unutrasnjost (Interior) je bila stotinama
	# metara od kuce. Normalizujemo na ciljanu velicinu i centriramo dno na 0.
	var target_h := 4.2
	if nm.contains("katun") or nm.contains("brvnara"):
		target_h = 3.4
	elif nm.contains("kamena") or nm.contains("Stone"):
		target_h = 4.6
	elif nm.contains("supa") or nm.contains("drvarnica"):
		target_h = 2.9
	elif nm.contains("kapela") or nm.contains("Chapel"):
		target_h = 6.5
	elif nm.contains("kula") or nm.contains("Tower"):
		target_h = 9.0
	elif nm.contains("avion"):
		target_h = 4.5
	elif nm.contains("kola") or nm.contains("cart"):
		target_h = 1.8
	elif nm.contains("znak"):
		target_h = 2.2
	elif nm.contains("stalka"):
		target_h = 1.6

	if found and size.y > 0.01:
		var ns := target_h / size.y
		# velicina nakon skaliranja (zadrzava proporcije)
		size = Vector3(size.x * ns, target_h, size.z * ns)
		# centriraj horizontalno, dno na y=0
		var cx := aabb.position.x + aabb.size.x * 0.5
		var cz := aabb.position.z + aabb.size.z * 0.5
		var dy := aabb.position.y
		# primijeni na SVE mesh cvorove kroz jedan Node3D wrapper
		var scaler := Node3D.new()
		scaler.name = "AutoFit"
		scaler.scale = Vector3(ns, ns, ns)
		scaler.position = Vector3(-cx * ns, -dy * ns, -cz * ns)
		while root.get_child_count() > 0:
			var ch: Node = root.get_child(0)
			root.remove_child(ch)
			# ocisti owner da ne bude "owner inconsistent" warninga
			_clear_owner(ch)
			scaler.add_child(ch)
		root.add_child(scaler)
		# aabb je sada poravnat na (0,0,0)..(size)
		aabb = AABB(Vector3.ZERO, size)

	# kolizija i anchor idu direktno u `root` (1.0 = 1 m, centrirano na X=0, Z=0).
	# Ne stavljati u AutoFit jer `size` vec ukljucuje skalu `ns`!
	var body := StaticBody3D.new()
	body.name = "HouseCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x * 0.92, size.y * 0.88, size.z * 0.92)
	shape.shape = bs
	shape.position = Vector3(0.0, size.y * 0.44, 0.0)
	body.add_child(shape)
	root.add_child(body)

	var anchor := Node3D.new()
	anchor.name = "InteriorAnchor"
	anchor.position = Vector3(0.0, 0.24, 0.0)
	root.add_child(anchor)

	return {"root": root, "anchor": anchor, "size": size}


## Rekurzivno ocisti `owner` (GLB instanca ga postavlja na root scene).
static func _clear_owner(n: Node) -> void:
	n.owner = null
	for c in n.get_children():
		_clear_owner(c)


static func _wall(parent: Node3D, length: float, h: float, pos: Vector3, yaw: float,
		has_door: bool, door_w: float, door_h: float, windows: bool,
		win_w: float, win_h: float, sill: float, key: String) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)

	if has_door:
		var side_w := length * 0.5 - door_w * 0.5
		if side_w > 0.02:
			for s in [-1.0, 1.0]:
				var seg := box(Vector3(side_w, h, WALL_T), key)
				seg.position = Vector3(s * (door_w * 0.5 + side_w * 0.5), h * 0.5, 0)
				holder.add_child(seg)
		var lint := box(Vector3(door_w + 0.06, h - door_h, WALL_T), key)
		lint.position = Vector3(0, door_h + (h - door_h) * 0.5, 0)
		holder.add_child(lint)
		if windows:
			_add_windows(holder, length, h, win_w, win_h, sill, key, [-length * 0.30, length * 0.30])
	else:
		if windows:
			_add_windows(holder, length, h, win_w, win_h, sill, key, [-length * 0.26, length * 0.26])
		else:
			var whole := box(Vector3(length, h, WALL_T), key)
			whole.position = Vector3(0, h * 0.5, 0)
			holder.add_child(whole)


static func _add_windows(holder: Node3D, length: float, h: float, win_w: float,
		win_h: float, sill: float, key: String, centers: Array) -> void:
	var prev := -length * 0.5
	for cx in centers:
		var x: float = cx
		var left_w: float = (x - win_w * 0.5) - prev
		if left_w > 0.02:
			var seg := box(Vector3(left_w, h, WALL_T), key)
			seg.position = Vector3(prev + left_w * 0.5, h * 0.5, 0)
			holder.add_child(seg)
		var below := box(Vector3(win_w, sill, WALL_T), key)
		below.position = Vector3(x, sill * 0.5, 0)
		holder.add_child(below)
		var above_h: float = h - sill - win_h
		if above_h > 0.02:
			var above := box(Vector3(win_w, above_h, WALL_T), key)
			above.position = Vector3(x, sill + win_h + above_h * 0.5, 0)
			holder.add_child(above)
		# glass + sill ledge
		var gl := box(Vector3(win_w * 0.92, win_h * 0.92, 0.06), "dark_hole")
		gl.position = Vector3(x, sill + win_h * 0.5, 0)
		holder.add_child(gl)
		var ledge := box(Vector3(win_w + 0.16, 0.07, WALL_T + 0.14), "stone_light")
		ledge.position = Vector3(x, sill - 0.02, 0)
		holder.add_child(ledge)
		prev = x + win_w * 0.5
	var tail: float = length * 0.5 - prev
	if tail > 0.02:
		var seg2 := box(Vector3(tail, h, WALL_T), key)
		seg2.position = Vector3(prev + tail * 0.5, h * 0.5, 0)
		holder.add_child(seg2)


static func _wall_colliders(w: float, d: float, h: float, door_side: int,
		door_w: float, door_h: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	var sides := [
		{ "len": w, "pos": Vector3(0, 0, d * 0.5), "rot": 0.0, "idx": 0 },
		{ "len": w, "pos": Vector3(0, 0, -d * 0.5), "rot": 0.0, "idx": 1 },
		{ "len": d, "pos": Vector3(w * 0.5, 0, 0), "rot": PI * 0.5, "idx": 2 },
		{ "len": d, "pos": Vector3(-w * 0.5, 0, 0), "rot": PI * 0.5, "idx": 3 },
	]
	for s in sides:
		var length: float = s["len"]
		var xf := Transform3D(Basis(Vector3.UP, s["rot"]), s["pos"])
		if s["idx"] == door_side:
			var side_w: float = length * 0.5 - door_w * 0.5
			if side_w > 0.02:
				for sign_side in [-1.0, 1.0]:
					var cs := CollisionShape3D.new()
					cs.shape = box_shape(Vector3(side_w, h, WALL_T))
					cs.transform = xf * Transform3D(Basis(),
						Vector3(sign_side * (door_w * 0.5 + side_w * 0.5), h * 0.5, 0))
					body.add_child(cs)
			var lint := CollisionShape3D.new()
			lint.shape = box_shape(Vector3(door_w + 0.2, h - door_h, WALL_T))
			lint.transform = xf * Transform3D(Basis(), Vector3(0, door_h + (h - door_h) * 0.5, 0))
			body.add_child(lint)
		else:
			var cs2 := CollisionShape3D.new()
			cs2.shape = box_shape(Vector3(length, h, WALL_T))
			cs2.transform = xf * Transform3D(Basis(), Vector3(0, h * 0.5, 0))
			body.add_child(cs2)
	# roof slab keeps grenades / camera out of the attic
	var roof_cs := CollisionShape3D.new()
	roof_cs.shape = box_shape(Vector3(w + 0.4, 0.28, d + 0.4))
	roof_cs.position = Vector3(0, h, 0)
	body.add_child(roof_cs)
	return body


# ----------------------------------------------------------------- interiors
## style: home | kafana | barracks | pillbox | mill | katun | chapel | tower
static func furnish(house: Dictionary, style: String, clues: Array = []) -> Node3D:
	var root: Node3D = house["root"]
	var size: Vector3 = house["size"]
	var w: float = size.x
	var d: float = size.z
	var room := Node3D.new()
	room.name = "Interior"
	# `root` je u pravim metrima (AutoFit skalira samo GLB mesh na metre),
	# a `size` i svi Stage4Props elementi su takodje u metrima -> ide u `root`.
	root.add_child(room)

	# hearth (all styles except pillbox)
	if style != "pillbox":
		var hearth := Node3D.new()
		hearth.position = Vector3(-w * 0.26, 0.22, -d * 0.5 + 0.52)
		var base := box(Vector3(1.5, 0.95, 0.66), "stone_dark")
		base.position = Vector3(0, 0.47, 0)
		hearth.add_child(base)
		var hood := box(Vector3(1.05, 0.85, 0.52), "stone_dark")
		hood.position = Vector3(0, 1.42, 0.02)
		hearth.add_child(hood)
		var fire := box(Vector3(0.72, 0.28, 0.40), "emissive_amber")
		fire.position = Vector3(0, 0.36, 0.24)
		hearth.add_child(fire)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.62, 0.30)
		light.light_energy = 1.3
		light.omni_range = 5.0
		light.position = Vector3(0, 0.8, 0.35)
		hearth.add_child(light)
		room.add_child(hearth)

	# table + benches (most styles)
	if style in ["home", "kafana", "mill", "katun", "chapel"]:
		var table := Node3D.new()
		table.position = Vector3(w * 0.14, 0.22, d * 0.10)
		var top := box(Vector3(1.5, 0.09, 0.92), "wood")
		top.position = Vector3(0, 0.74, 0)
		table.add_child(top)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var leg := box(Vector3(0.09, 0.72, 0.09), "wood_dark")
				leg.position = Vector3(sx * 0.62, 0.36, sz * 0.36)
				table.add_child(leg)
		for sz2 in [-1.0, 1.0]:
			var bench := box(Vector3(1.35, 0.08, 0.30), "wood")
			bench.position = Vector3(0, 0.44, sz2 * 0.70)
			table.add_child(bench)
		room.add_child(table)

		var lamp := cyl(0.09, 0.20, "iron_rust", 0.07, 8)
		lamp.position = table.position + Vector3(0.44, 1.0, 0.0)
		room.add_child(lamp)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.78, 0.48)
		glow.light_energy = 0.75
		glow.omni_range = 3.6
		glow.position = table.position + Vector3(0.44, 1.12, 0.0)
		room.add_child(glow)

		# clues laid out on the table surface
		for i in clues.size():
			var cue: Dictionary = clues[i]
			var note := ClueNoteStage4.new()
			note.clue_id = str(cue.get("id", "clue_%d" % i))
			note.title = str(cue.get("title", "Zabiljeska"))
			note.body = str(cue.get("body", ""))
			note.position = table.position + Vector3(-0.28 + i * 0.52, 0.82, 0.06)
			room.add_child(note)

	match style:
		"kafana": _furnish_kafana(room, w, d)
		"barracks": _furnish_barracks(room, w, d)
		"pillbox": _furnish_pillbox(room, w, d)
		"mill": _furnish_mill(room, w, d)
		"katun": _furnish_katun(room, w, d)
		"chapel": _furnish_chapel(room, w, d)
		"tower": _furnish_tower(room, w, d)
		_: _furnish_home(room, w, d)
	return room


static func _furnish_home(room: Node3D, w: float, d: float) -> void:
	var bed := Node3D.new()
	bed.position = Vector3(w * 0.5 - 1.0, 0.22, d * 0.5 - 0.95)
	var frame := box(Vector3(1.0, 0.32, 1.95), "wood_dark")
	frame.position = Vector3(0, 0.16, 0)
	bed.add_child(frame)
	var mattress := box(Vector3(0.94, 0.15, 1.85), "cloth_white")
	mattress.position = Vector3(0, 0.39, 0)
	bed.add_child(mattress)
	var blanket := box(Vector3(0.97, 0.07, 1.05), "cloth_blue")
	blanket.position = Vector3(0, 0.47, 0.32)
	bed.add_child(blanket)
	var pillow := box(Vector3(0.58, 0.11, 0.32), "cloth_white")
	pillow.position = Vector3(0, 0.50, -0.72)
	bed.add_child(pillow)
	room.add_child(bed)

	var shelf := box(Vector3(1.5, 0.07, 0.30), "wood")
	shelf.position = Vector3(-w * 0.5 + 1.05, 1.68, -d * 0.5 + 0.34)
	room.add_child(shelf)
	for i in 3:
		var jar := cyl(0.085, 0.21, "stone_light", 0.055, 7)
		jar.position = Vector3(-w * 0.5 + 0.55 + i * 0.45, 1.84, -d * 0.5 + 0.34)
		room.add_child(jar)

	var trunk := box(Vector3(0.92, 0.52, 0.52), "wood_dark")
	trunk.position = Vector3(-w * 0.5 + 0.72, 0.50, d * 0.5 - 0.58)
	room.add_child(trunk)
	var lid := box(Vector3(0.96, 0.07, 0.56), "wood")
	lid.position = Vector3(-w * 0.5 + 0.72, 0.80, d * 0.5 - 0.58)
	room.add_child(lid)


static func _furnish_kafana(room: Node3D, w: float, d: float) -> void:
	for i in 3:
		var t := Node3D.new()
		t.position = Vector3(-w * 0.28 + i * 1.45, 0.22, d * 0.06 + (i % 2) * 0.85)
		var top := cyl(0.48, 0.08, "wood", -1, 12)
		top.position = Vector3(0, 0.73, 0)
		t.add_child(top)
		var leg := cyl(0.07, 0.71, "wood_dark", -1, 8)
		leg.position = Vector3(0, 0.355, 0)
		t.add_child(leg)
		for a in 3:
			var ang := a * TAU / 3.0
			var st := box(Vector3(0.34, 0.06, 0.34), "wood")
			st.position = Vector3(cos(ang) * 0.70, 0.44, sin(ang) * 0.70)
			st.rotation.y = ang
			t.add_child(st)
			var sl := box(Vector3(0.06, 0.43, 0.06), "wood_dark")
			sl.position = st.position - Vector3(0, 0.235, 0)
			t.add_child(sl)
		var mug := cyl(0.055, 0.12, "iron_rust", -1, 7)
		mug.position = Vector3(0.12, 0.83, 0.06)
		t.add_child(mug)
		room.add_child(t)

	var counter := box(Vector3(2.3, 0.94, 0.54), "wood_dark")
	counter.position = Vector3(w * 0.5 - 1.45, 0.47, -d * 0.5 + 0.68)
	room.add_child(counter)
	for i in 3:
		var barrel := cyl(0.29, 0.84, "wood", -1, 10)
		barrel.position = Vector3(w * 0.5 - 2.25 + i * 0.70, 0.66, -d * 0.5 + 1.30)
		room.add_child(barrel)
		for hoop_y in [0.20, 0.60]:
			var ring := cyl(0.305, 0.05, "iron_rust", -1, 10)
			ring.position = barrel.position + Vector3(0, hoop_y - 0.42, 0)
			room.add_child(ring)
	var hang := OmniLight3D.new()
	hang.light_color = Color(1.0, 0.80, 0.52)
	hang.light_energy = 1.0
	hang.omni_range = 5.5
	hang.position = Vector3(0, 2.15, 0)
	room.add_child(hang)


static func _furnish_barracks(room: Node3D, w: float, d: float) -> void:
	for i in 2:
		var bunk := Node3D.new()
		bunk.position = Vector3(-w * 0.5 + 0.72, 0.22, -d * 0.20 + i * 1.55)
		for lvl in 2:
			var slab := box(Vector3(0.84, 0.10, 1.92), "wood")
			slab.position = Vector3(0, 0.34 + lvl * 0.84, 0)
			bunk.add_child(slab)
			var mt := box(Vector3(0.77, 0.09, 1.82), "canvas_green")
			mt.position = Vector3(0, 0.43 + lvl * 0.84, 0)
			bunk.add_child(mt)
		for sz in [-1.0, 1.0]:
			var post := box(Vector3(0.075, 1.62, 0.075), "iron")
			post.position = Vector3(0.41, 0.84, sz * 0.90)
			bunk.add_child(post)
		room.add_child(bunk)

	var desk := box(Vector3(1.65, 0.77, 0.82), "wood_dark")
	desk.position = Vector3(w * 0.5 - 1.08, 0.60, -d * 0.5 + 0.84)
	room.add_child(desk)
	var map_sheet := box(Vector3(0.98, 0.02, 0.58), "cloth_white")
	map_sheet.position = desk.position + Vector3(-0.10, 0.05, 0.02)
	room.add_child(map_sheet)
	var radio := box(Vector3(0.40, 0.28, 0.25), "iron")
	radio.position = desk.position + Vector3(0.54, 0.19, 0.04)
	room.add_child(radio)
	var ant := cyl(0.011, 0.86, "iron", 0.008, 5)
	ant.position = radio.position + Vector3(0.11, 0.57, 0)
	room.add_child(ant)
	var rack := box(Vector3(0.13, 0.13, 1.45), "wood_dark")
	rack.position = Vector3(w * 0.5 - 0.34, 1.32, 0.38)
	room.add_child(rack)


static func _furnish_pillbox(room: Node3D, w: float, d: float) -> void:
	var bench := box(Vector3(w * 0.80, 0.14, 0.60), "concrete")
	bench.position = Vector3(0, 0.92, -d * 0.5 + 0.52)
	room.add_child(bench)
	for i in 2:
		var crate := box(Vector3(0.54, 0.31, 0.35), "wood_dark")
		crate.position = Vector3(-w * 0.28 + i * 0.68, 0.40, d * 0.20)
		room.add_child(crate)
	var mg := box(Vector3(0.10, 0.13, 1.05), "iron")
	mg.position = Vector3(0.10, 1.03, -d * 0.5 + 0.58)
	room.add_child(mg)


static func _furnish_mill(room: Node3D, w: float, d: float) -> void:
	var sa := cyl(0.60, 0.21, "stone_light", -1, 14)
	sa.position = Vector3(-w * 0.24, 0.90, -d * 0.18)
	room.add_child(sa)
	var sb := cyl(0.56, 0.19, "stone", -1, 14)
	sb.position = Vector3(-w * 0.24, 1.10, -d * 0.18)
	room.add_child(sb)
	var axis := cyl(0.09, 0.88, "wood_dark", -1, 8)
	axis.position = Vector3(-w * 0.24, 1.18, -d * 0.18)
	room.add_child(axis)
	for i in 4:
		var sack := sphere(0.25, "hay", false, 8)
		sack.position = Vector3(w * 0.5 - 0.58 - (i % 2) * 0.48, 0.50, d * 0.5 - 0.68 - i * 0.33)
		sack.scale = Vector3(1.0, 1.32, 1.0)
		room.add_child(sack)


static func _furnish_katun(room: Node3D, w: float, d: float) -> void:
	var cauldron := sphere(0.32, "iron", true, 10)
	cauldron.position = Vector3(-w * 0.20, 0.52, -d * 0.28)
	room.add_child(cauldron)
	var rack := box(Vector3(1.75, 0.08, 0.38), "wood")
	rack.position = Vector3(0, 1.70, -d * 0.5 + 0.38)
	room.add_child(rack)
	for i in 5:
		var wheel := cyl(0.13, 0.09, "hay", -1, 10)
		wheel.rotation.x = PI * 0.5
		wheel.position = Vector3(-0.68 + i * 0.34, 1.58, -d * 0.5 + 0.38)
		room.add_child(wheel)
	for i in 2:
		var bale := box(Vector3(0.78, 0.48, 0.48), "cloth_white")
		bale.position = Vector3(w * 0.5 - 0.68, 0.49, -d * 0.28 + i * 0.68)
		room.add_child(bale)


static func _furnish_chapel(room: Node3D, w: float, d: float) -> void:
	# iconostasis hint + two pews + candle glow
	for i in 2:
		var pew := box(Vector3(w * 0.62, 0.09, 0.34), "wood_dark")
		pew.position = Vector3(0, 0.46, d * 0.24 - i * 0.85)
		room.add_child(pew)
		var back := box(Vector3(w * 0.62, 0.38, 0.07), "wood_dark")
		back.position = pew.position + Vector3(0, 0.22, 0.16)
		room.add_child(back)
	var altar := box(Vector3(1.35, 0.95, 0.55), "stone_light")
	altar.position = Vector3(0, 0.47, -d * 0.5 + 0.62)
	room.add_child(altar)
	for i in 3:
		var candle := cyl(0.025, 0.20, "cloth_white", -1, 6)
		candle.position = Vector3(-0.35 + i * 0.35, 1.05, -d * 0.5 + 0.62)
		room.add_child(candle)
		var flame := sphere(0.035, "emissive_amber", false, 5)
		flame.position = candle.position + Vector3(0, 0.13, 0)
		room.add_child(flame)


static func _furnish_tower(room: Node3D, w: float, d: float) -> void:
	# small garrison room at the tower base
	var table := box(Vector3(1.2, 0.08, 0.8), "wood_dark")
	table.position = Vector3(0, 0.78, 0)
	room.add_child(table)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := box(Vector3(0.08, 0.76, 0.08), "wood_dark")
			leg.position = table.position + Vector3(sx * 0.48, -0.38, sz * 0.30)
			room.add_child(leg)
	var lamp := cyl(0.08, 0.18, "iron_rust", 0.06, 8)
	lamp.position = Vector3(0.35, 0.92, 0.1)
	room.add_child(lamp)


# -------------------------------------------------------- special structures
static func make_watchtower(height: float = 5.2) -> Dictionary:
	var root := Node3D.new()
	root.name = "Watchtower"
	var half := 1.12
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := box(Vector3(0.17, height, 0.17), "wood_dark")
			post.position = Vector3(sx * half, height * 0.5, sz * half)
			root.add_child(post)
	for lvl in 2:
		var y := 1.1 + lvl * (height - 2.0) * 0.6
		for s in [-1.0, 1.0]:
			var brace := box(Vector3(half * 2.0, 0.09, 0.07), "wood")
			brace.position = Vector3(0, y, -half)
			brace.rotation.z = s * 0.42
			root.add_child(brace)
	var deck := box(Vector3(half * 2.4, 0.14, half * 2.4), "wood")
	deck.position = Vector3(0, height, 0)
	root.add_child(deck)
	for s in [-1.0, 1.0]:
		var rz := box(Vector3(half * 2.4, 0.08, 0.07), "wood_dark")
		rz.position = Vector3(0, height + 0.86, s * half * 1.2)
		root.add_child(rz)
		var rx := box(Vector3(0.07, 0.08, half * 2.4), "wood_dark")
		rx.position = Vector3(s * half * 1.2, height + 0.86, 0)
		root.add_child(rx)
		for i in 3:
			var bal := box(Vector3(0.05, 0.86, 0.05), "wood")
			bal.position = Vector3(s * half * 1.2, height + 0.43, -half * 1.05 + i * half * 1.05)
			root.add_child(bal)
	var canopy := gable(half * 2.4, half * 2.4, 0.68, 0.24, "slate")
	canopy.position = Vector3(0, height + 1.72, 0)
	root.add_child(canopy)
	var lad := ladder(height - 0.4, 0.60)
	lad.rotation.x = 0.10
	lad.position = Vector3(0, 0, half * 1.28)
	root.add_child(lad)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var deck_cs := CollisionShape3D.new()
	deck_cs.shape = box_shape(Vector3(half * 2.4, 0.18, half * 2.4))
	deck_cs.position = Vector3(0, height, 0)
	body.add_child(deck_cs)
	var fit2 := root.get_node_or_null("AutoFit") as Node3D
	if fit2:
		fit2.add_child(body)
	else:
		root.add_child(body)
	return { "root": root, "deck_height": height }


static func ladder(height: float, width: float = 0.60) -> Node3D:
	var root := Node3D.new()
	for s in [-1.0, 1.0]:
		var rail := box(Vector3(0.08, height, 0.08), "wood")
		rail.position = Vector3(s * width * 0.5, height * 0.5, 0)
		root.add_child(rail)
	var rungs := maxi(2, int(height / 0.32))
	for i in rungs:
		var rung := box(Vector3(width, 0.05, 0.05), "wood_dark")
		rung.position = Vector3(0, 0.18 + i * (height - 0.3) / float(rungs), 0)
		root.add_child(rung)
	return root


static func make_sandbag_nest(radius: float = 1.4) -> Node3D:
	var root := Node3D.new()
	var bags := 14
	for i in bags:
		var a := TAU * float(i) / float(bags)
		var bag := box(Vector3(0.54, 0.21, 0.31), "canvas")
		bag.position = Vector3(cos(a) * radius, 0.10, sin(a) * radius)
		bag.rotation.y = -a + PI * 0.5
		root.add_child(bag)
		if i % 2 == 0:
			var bag2 := box(Vector3(0.54, 0.21, 0.31), "canvas")
			bag2.position = bag.position + Vector3(0, 0.20, 0)
			bag2.rotation.y = bag.rotation.y
			root.add_child(bag2)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	# Ogradni prsten vreca (ostavlja prolaz na indeksu 0 da se moze uci u zaklon)
	for i in range(1, bags):
		var a := TAU * float(i) / float(bags)
		var cs := CollisionShape3D.new()
		cs.shape = box_shape(Vector3(0.56, 0.46, 0.34))
		cs.position = Vector3(cos(a) * radius, 0.23, sin(a) * radius)
		cs.rotation.y = -a + PI * 0.5
		body.add_child(cs)
	root.add_child(body)
	return root


static func make_cheval_de_frise(length: float = 2.4) -> Node3D:
	var root := Node3D.new()
	for s in [0.7, -0.7]:
		var beam := box(Vector3(length, 0.10, 0.10), "wood_dark")
		beam.rotation.z = s
		root.add_child(beam)
	for i in 5:
		var barb := cyl(0.02, length * 0.7, "iron_rust", 0.02, 4)
		barb.rotation.x = PI * 0.5
		barb.position = Vector3(-length * 0.35 + i * length * 0.175, 0.34, 0)
		root.add_child(barb)
	return root


static func make_flag(key: String = "cloth_red", height: float = 4.0) -> Node3D:
	var root := Node3D.new()
	var pole := cyl(0.05, height, "iron", 0.04, 6)
	pole.position = Vector3(0, height * 0.5, 0)
	root.add_child(pole)
	var flag := plate(Vector2(1.25, 0.72), key)
	flag.position = Vector3(0.64, height - 0.48, 0)
	root.add_child(flag)
	return root


# --- short aliases used throughout this file ---
static func box(size: Vector3, key: String) -> MeshInstance3D:
	return Stage4Props.box(size, key)

static func cyl(radius: float, height: float, key: String, top: float = -1.0, segs: int = 10) -> MeshInstance3D:
	return Stage4Props.cyl(radius, height, key, top, segs)

static func sphere(radius: float, key: String, hemi: bool = false, segs: int = 10) -> MeshInstance3D:
	return Stage4Props.sphere(radius, key, hemi, segs)

static func plate(size: Vector2, key: String) -> MeshInstance3D:
	return Stage4Props.plate(size, key)

static func prism(size: Vector3, key: String) -> MeshInstance3D:
	return Stage4Props.prism(size, key)

static func gable(width: float, depth: float, rise: float, overhang: float, key: String) -> MeshInstance3D:
	return Stage4Props.gable(width, depth, rise, overhang, key)

static func box_shape(size: Vector3) -> BoxShape3D:
	return Stage4Props.box_shape(size)

static func cyl_shape(radius: float, height: float) -> CylinderShape3D:
	return Stage4Props.cyl_shape(radius, height)
