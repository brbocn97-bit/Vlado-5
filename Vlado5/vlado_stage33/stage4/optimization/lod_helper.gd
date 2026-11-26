class_name LodHelper
extends RefCounted
## LodHelper — distance-based mesh LOD for Stage 4 props.
##
## Godot's automatic `visibility_range` only culls; it cannot swap in a cheaper
## mesh. Stage 4 has hundreds of small props (fences, logs, crates, barrels)
## that are sub-pixel past 80 m, so each of them gets two levels:
##
##   LOD0  the real mesh                      up to `near_m`
##   LOD1  a box of the same bounds, 12 tris  from `near_m` to `far_m`
##   (gone)                                   past `far_m`
##
## The LOD1 stand-in keeps the object's silhouette and, critically, keeps its
## material, so a distant village still reads as a village instead of popping.

const DEFAULT_NEAR := 90.0
const DEFAULT_FAR := 340.0


## Attaches a cheap stand-in to a MeshInstance3D and drives it by distance.
## The original mesh is untouched.
static func apply(mi: MeshInstance3D, near_m := DEFAULT_NEAR, far_m := DEFAULT_FAR) -> void:
	if mi == null or mi.mesh == null:
		return
	var aabb := mi.get_aabb()
	if aabb.size == Vector3.ZERO:
		return
	var proxy := MeshInstance3D.new()
	proxy.name = "LOD1"
	var bm := BoxMesh.new()
	bm.size = aabb.size
	proxy.mesh = bm
	proxy.material_override = mi.material_override if mi.material_override else _first_material(mi)
	var parent_node := mi.get_parent()
	if parent_node == null:
		proxy.queue_free()
		return
	proxy.transform = mi.transform * Transform3D(Basis(), aabb.get_center())
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	proxy.visible = false
	parent_node.add_child(proxy)
	mi.set_meta("_has_lod1", true)

	var watcher := LODWatcher.new()
	watcher.setup(mi, proxy, near_m, far_m)
	proxy.add_child(watcher)


static func _first_material(mi: MeshInstance3D) -> Material:
	if mi.mesh.get_surface_count() > 0:
		return mi.mesh.surface_get_material(0)
	return null


## Recursively adds LOD to every mesh under `root` that is small enough to
## matter (large buildings keep their full mesh).
static func apply_to_tree(root: Node, near_m := DEFAULT_NEAR, far_m := DEFAULT_FAR) -> int:
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		var size := mesh_inst.get_aabb().size
		var longest: float = maxf(size.x, maxf(size.y, size.z))
		# skip heroes (buildings, landmarks) and sub-centimetre clutter
		if longest > 12.0 or longest < 0.25:
			continue
		if mesh_inst.has_meta("_has_lod1") or mesh_inst.name == "LOD1":
			continue
		apply(mesh_inst, near_m, far_m)
		n += 1
	return n
