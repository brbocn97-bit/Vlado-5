class_name Stage4TerenProps
extends RefCounted
## Stage4TerenProps — postavlja 25 GLB modela iz assets/models/teren/ u svijet.
##
## Ovi modeli su VISOKOG KVALITETA (korisnikovi originali) i zamjenjuju
## proceduralnu plosnatu travu tamo gdje su najvidljiviji.
##
## Sve je instancirano kroz MultiMesh gdje god je moguce, da ne ubijemo FPS.

const BASE := "res://assets/models/teren/"

# --- modeli ---
const M_PUT_ZEMLJANI := "put_zemljani.glb"
const M_PUT_GOLI := "put_goli.glb"
const M_PUT_STAZE := "put_staze.glb"
const M_PUT_IVICA := "put_ivica.glb"
const M_KALDRMA := "kaldrma.glb"
const M_TRAVA_ZELENA := "trava_zelena.glb"
const M_TRAVA_VISOKA := "trava_visoka.glb"
const M_TRAVA_SUHA := "trava_suha.glb"
const M_TRAVA_BLIZU := "trava_blizu.glb"
const M_SIBLJAK := "sibljak.glb"
const M_LITICA := "litica.glb"
const M_STIJENA_KOSA := "stijena_kosa.glb"
const M_STIJENA_PLITKA := "stijena_plitka.glb"
const M_STIJENE_RAZBIJENE := "stijene_razbijene.glb"
const M_ZEMLJA := "zemlja.glb"
const M_BLATO := "blato.glb"
const M_LOKVA := "lokva.glb"
const M_LISCE := "lisce.glb"
const M_LISCE_JAVOR := "lisce_javor.glb"
const M_KLADA := "klada.glb"
const M_DRVENA_OGRADA := "drvena_ograda.glb"
const M_METALNA_OGRADA := "metalna_ograda.glb"
const M_STABLO_BREZA := "stablo_breza.glb"
const M_STABLO_HRAST := "stablo_hrast.glb"
const M_TEREN_DALEKI := "teren_daleki.glb"


static func _exists(rel: String) -> bool:
	return ResourceLoader.exists(BASE + rel)


static func _scene(rel: String) -> PackedScene:
	if not _exists(rel):
		return null
	return load(BASE + rel) as PackedScene


## Napravi MultiMeshInstance3D od GLB scene (jedan draw call za sve instance).
## `xf` je niz Transform3D pozicija.
static func make_multimesh(name: String, rel: String, xf: Array,
		vis_end: float = 200.0) -> MultiMeshInstance3D:
	var packed := _scene(rel)
	if packed == null or xf.is_empty():
		return null

	var root := packed.instantiate()
	var mi := _first_mesh_instance(root)
	if mi == null:
		root.free()
		return null

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mi.mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])

	var out := MultiMeshInstance3D.new()
	out.name = name
	out.multimesh = mm
	out.visibility_range_end = vis_end
	out.visibility_range_end_margin = vis_end * 0.1
	out.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.free()
	return out


## Prvi MeshInstance3D u stablu (GLB moze imati vise). Vraca i material override.
static func _first_mesh_instance(n: Node) -> MeshInstance3D:
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			# primijeni transform roditelja na mesh da MultiMesh dobije tacnu skalu
			var mi := c as MeshInstance3D
			if not mi.transform.is_equal_approx(Transform3D.IDENTITY):
				mi.mesh = mi.mesh.duplicate()
			return mi
		for ch in c.get_children():
			stack.append(ch)
	return null


## Postavi JEDAN model na teren (za velike, rijetke stvari: litice, klade, ograde).
static func place_one(parent: Node3D, rel: String, pos: Vector3, yaw: float = 0.0,
		scale_mul: float = 1.0) -> Node3D:
	var packed := _scene(rel)
	if packed == null or parent == null:
		return null
	var inst: Node3D = packed.instantiate()
	if inst == null:
		return null
	# BUG (popravljen): GLB modeli imaju ogroman offset od koordinatnog
	# pocetka (npr. litica centar je na x=-127 m u sirovim jedinicama).
	# Bez centriranja model se pojavi 1-2 m dalje od zadate tacke.
	var local_a := model_aabb(rel)
	var c := local_a.get_center()
	var wrapper := Node3D.new()
	wrapper.name = inst.name
	inst.position = Vector3(-c.x, -local_a.position.y, -c.z)
	wrapper.add_child(inst)
	wrapper.position = pos
	wrapper.rotation.y = yaw
	if not is_equal_approx(scale_mul, 1.0):
		wrapper.scale = Vector3(scale_mul, scale_mul, scale_mul)
	parent.add_child(wrapper)
	return wrapper


## Vraca AABB modela u lokalnim koordinatama (za tacno postavljanje na zemlju).
static func model_aabb(rel: String) -> AABB:
	var packed := _scene(rel)
	if packed == null:
		return AABB()
	var inst := packed.instantiate()
	if inst == null:
		return AABB()
	# BUG (popravljen): stara verzija je koristila samo mi.transform, pa se
	# gubila skala iz roditeljskih cvorova GLB-a (Sketchfab_model/model.fbx/...).
	# litica je izlazila 157x80x40 umjesto ~1.6 m.
	var box := AABB()
	var first := true
	var stack: Array = [[inst, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var c: Node = item[0]
		var xf: Transform3D = item[1]
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			var b: AABB = xf * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for ch in c.get_children():
			var cxf: Transform3D = xf
			if ch is Node3D:
				cxf = xf * (ch as Node3D).transform
			stack.append([ch, cxf])
	inst.free()
	return box


## Skaliraj tako da model bude zadate velicine (najveca dimenzija).
static func size_for(rel: String, target_m: float) -> float:
	var a := model_aabb(rel)
	if a.size == Vector3.ZERO:
		return 1.0
	var longest: float = maxf(a.size.x, maxf(a.size.y, a.size.z))
	if longest < 0.0001:
		return 1.0
	return target_m / longest


## Koliko modela postoji (za debug).
static func count_available() -> int:
	var n := 0
	for f in [M_PUT_ZEMLJANI, M_PUT_GOLI, M_PUT_STAZE, M_PUT_IVICA, M_KALDRMA,
			M_TRAVA_ZELENA, M_TRAVA_VISOKA, M_TRAVA_SUHA, M_TRAVA_BLIZU,
			M_SIBLJAK, M_LITICA, M_STIJENA_KOSA, M_STIJENA_PLITKA,
			M_STIJENE_RAZBIJENE, M_ZEMLJA, M_BLATO, M_LOKVA, M_LISCE,
			M_LISCE_JAVOR, M_KLADA, M_DRVENA_OGRADA, M_METALNA_OGRADA,
			M_STABLO_BREZA, M_STABLO_HRAST, M_TEREN_DALEKI]:
		if _exists(f):
			n += 1
	return n
