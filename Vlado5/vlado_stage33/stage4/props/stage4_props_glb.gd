class_name Stage4PropsGLB
extends RefCounted
## Stage4PropsGLB — učitava prave GLB modele umjesto proceduralnih.
##
## Modeli su u res://assets/models/{zgrade,vegetacija,oprema,teren}/
##
## Ako model ne postoji, vraća null i pozivajući kod nastavlja sa
## proceduralnom verzijom. Tako igra nikad ne puca zbog nedostajućeg fajla.

const BASE := "res://assets/models/"

static var _cache: Dictionary = {}


## Učitaj model po relativnoj putanji, npr. "zgrade/kuca_kamena.glb".
## Vraća Node3D ili null.
static func load_model(rel_path: String) -> Node3D:
	var full := BASE + rel_path
	if _cache.has(full):
		var cached_scene := _cache[full] as PackedScene
		if cached_scene == null:
			return null
		var dup := cached_scene.instantiate() as Node3D
		if dup:
			dup.name = rel_path.get_file().get_basename()
		return dup

	if not ResourceLoader.exists(full):
		_cache[full] = null
		return null

	var packed := load(full) as PackedScene
	if packed == null:
		_cache[full] = null
		return null

	var inst := packed.instantiate() as Node3D
	if inst == null:
		_cache[full] = null
		return null

	_cache[full] = packed
	inst.name = rel_path.get_file().get_basename()
	return inst


## Isto kao load_model, ali vraća PackedScene za MultiMesh/efficient reuse.
static func load_scene(rel_path: String) -> PackedScene:
	var full := BASE + rel_path
	if not ResourceLoader.exists(full):
		return null
	return load(full) as PackedScene


## Postavi model na teren, sa rotacijom oko Y ose.
static func place_model(parent: Node3D, rel_path: String, x: float, z: float,
		y_world: float, yaw: float = 0.0, scale_mul: float = 1.0) -> Node3D:
	var m := load_model(rel_path)
	if m == null:
		return null
	m.position = Vector3(x, y_world, z)
	m.rotation.y = yaw
	if not is_equal_approx(scale_mul, 1.0):
		m.scale = Vector3.ONE * scale_mul
	parent.add_child(m)
	return m


## Provjeri koji modeli postoje — korisno za debug.
static func available() -> Dictionary:
	var out := {}
	for cat in ["zgrade", "vegetacija", "oprema", "teren"]:
		var dir := DirAccess.open(BASE + cat)
		if dir == null:
			out[cat] = []
			continue
		var names: Array = []
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".glb"):
				names.append(f)
			f = dir.get_next()
		dir.list_dir_end()
		names.sort()
		out[cat] = names
	return out
