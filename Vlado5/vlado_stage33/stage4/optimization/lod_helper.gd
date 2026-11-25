class_name LodHelper
extends RefCounted
## Distance-culls small props using renderer visibility ranges. Avoids
## box-shaped impostors and per-prop script watchers.

const DEFAULT_FAR := 220.0


static func apply(mi: MeshInstance3D, far_m := DEFAULT_FAR) -> bool:
	if mi == null or mi.mesh == null:
		return false
	var aabb := mi.get_aabb()
	if aabb.size == Vector3.ZERO:
		return false
	mi.visibility_range_end = far_m
	mi.visibility_range_end_margin = minf(far_m * 0.1, 18.0)
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return true


## Applies native distance culling to small meshes while leaving buildings and
## landmarks untouched.
static func apply_to_tree(root: Node, far_m := DEFAULT_FAR) -> int:
	if root == null:
		return 0
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		var size := mesh_inst.get_aabb().size
		var longest: float = maxf(size.x, maxf(size.y, size.z))
		# Skip buildings, landmarks, and sub-centimetre details.
		if longest > 12.0 or longest < 0.25:
			continue
		if apply(mesh_inst, far_m):
			n += 1
	return n
