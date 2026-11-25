
class_name MontenegroTerrainData
extends RefCounted

const WORLD_SIZE := 1400.0
const HALF_WORLD := 700.0

const BRIDGE_CENTER := Vector2(23.53, -16.0)
const BRIDGE_DECK_Y := 2.05
const VILLAGE_CENTER := Vector2(-26.0, 4.0)
const VILLAGE_ELEV := 2.60

# ============================================================================
# STAGE 4 — outer region terraces and connector passes
# ----------------------------------------------------------------------------
# The Stage 3.2 heightfield is a bowl: flat only near the origin (|h| ~ 2 m,
# ~4 deg) and rising to 112-175 m with 30-63 deg slopes toward the world edges.
# The six Stage 4 regions all sit out there, so without help every settlement
# would be half-buried in a mountainside. These terraces cut flat benches for
# each region and grade gentle passes between them, reusing the same blend
# approach the original village terrace uses. The river/stream carving runs
# after this block and therefore still cuts through everything.
# ============================================================================
const S4_SITES := [
	{"id": "Krupa_Valley",      "c": Vector2(0.0, 0.0),      "h": 1.95, "r": 150.0, "blend": 120.0},
	{"id": "Crnca_Village",     "c": Vector2(-340.0, 10.0),  "h": 24.0, "r": 118.0, "blend": 96.0},
	{"id": "Security_Checkpoint", "c": Vector2(340.0, -90.0),  "h": 32.0, "r": 96.0,  "blend": 88.0},
	{"id": "Durmitor_Forest_Hideout", "c": Vector2(-250.0, -350.0),"h": 42.0, "r": 84.0,  "blend": 92.0},
	{"id": "Krupa_Canyon_Crossings", "c": Vector2(100.0, 340.0),  "h": 28.0, "r": 104.0, "blend": 100.0},
	{"id": "Lovcen_High_Peaks",  "c": Vector2(360.0, 290.0),  "h": 66.0, "r": 96.0,  "blend": 96.0},
]

const S4_CORRIDORS := [
	{"a": Vector2(0.0, 0.0),      "b": Vector2(-340.0, 10.0),  "ha": 1.95, "hb": 24.0, "w": 17.0, "blend": 30.0},
	{"a": Vector2(0.0, 0.0),      "b": Vector2(340.0, -90.0),  "ha": 1.95, "hb": 32.0, "w": 17.0, "blend": 30.0},
	{"a": Vector2(-340.0, 10.0),  "b": Vector2(-250.0, -350.0),"ha": 24.0, "hb": 42.0, "w": 15.0, "blend": 28.0},
	{"a": Vector2(0.0, 0.0),      "b": Vector2(100.0, 340.0),  "ha": 1.95, "hb": 28.0, "w": 17.0, "blend": 30.0},
	{"a": Vector2(100.0, 340.0),  "b": Vector2(360.0, 290.0),  "ha": 28.0, "hb": 66.0, "w": 16.0, "blend": 28.0},
]


var _noise_macro: FastNoiseLite
var _noise_detail: FastNoiseLite
var _noise_ridge: FastNoiseLite

var _road_pts: PackedVector2Array
var _extra_road_pts: Array[PackedVector2Array] = []

var _trail_pts: PackedVector2Array
var _extra_trail_pts: Array[PackedVector2Array] = []

var _stream_pts: PackedVector2Array


func _init() -> void:
	_noise_macro = FastNoiseLite.new()
	_noise_macro.seed = 1943
	_noise_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_macro.frequency = 0.0022
	_noise_macro.fractal_octaves = 5
	_noise_macro.fractal_lacunarity = 2.05
	_noise_macro.fractal_gain = 0.48

	_noise_detail = FastNoiseLite.new()
	_noise_detail.seed = 1945
	_noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_detail.frequency = 0.028
	_noise_detail.fractal_octaves = 3

	_noise_ridge = FastNoiseLite.new()
	_noise_ridge.seed = 1941
	_noise_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_ridge.frequency = 0.0028
	_noise_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_noise_ridge.fractal_octaves = 4

	# Main road: Crnca -> Krupa Valley -> Security checkpoint.
	_road_pts = PackedVector2Array([
		Vector2(-455.0, -10.0),
		Vector2(-330.0, 18.0),
		Vector2(-210.0, 42.0),
		Vector2(-105.0, 38.0),
		Vector2(-22.0, 12.0),
		Vector2(-2.0, 4.0),
		Vector2(23.53, -16.0),
		Vector2(82.0, -32.0),
		Vector2(178.0, -95.0),
		Vector2(275.0, -112.0),
		Vector2(385.0, -88.0),
		Vector2(515.0, -45.0)
	])

	# Southern canyon road.
	_extra_road_pts.append(PackedVector2Array([
		Vector2(-2.0, 4.0),
		Vector2(24.0, 92.0),
		Vector2(62.0, 205.0),
		Vector2(112.0, 330.0),
		Vector2(145.0, 455.0)
	]))

	# North partisan trail.
	_trail_pts = PackedVector2Array([
		Vector2(-12.0, 8.0),
		Vector2(-44.0, -68.0),
		Vector2(-118.0, -162.0),
		Vector2(-215.0, -265.0),
		Vector2(-285.0, -395.0)
	])

	# Smugglers' trail.
	_extra_trail_pts.append(PackedVector2Array([
		Vector2(-345.0, -18.0),
		Vector2(-320.0, -185.0),
		Vector2(-285.0, -395.0)
	]))

	# Alpine ridge track.
	_extra_trail_pts.append(PackedVector2Array([
		Vector2(345.0, -90.0),
		Vector2(375.0, 85.0),
		Vector2(345.0, 255.0),
		Vector2(265.0, 385.0),
		Vector2(145.0, 455.0)
	]))

	_stream_pts = _build_smooth_stream_pts()


func _build_smooth_stream_pts() -> PackedVector2Array:
	var ctrl := PackedVector2Array([
		Vector2(-110.0, -145.0),
		Vector2(-92.0, -112.0),
		Vector2(-74.0, -96.0),
		Vector2(-52.0, -76.0),
		Vector2(-26.0, -58.0),
		Vector2(4.0, -49.0),
		Vector2(31.78, -45.0)
	])

	var out := PackedVector2Array()
	var n := ctrl.size()

	for i in range(n - 1):
		var p0 := ctrl[maxi(0, i - 1)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(n - 1, i + 2)]

		for s in range(5):
			var t := float(s) / 5.0
			var t2 := t * t
			var t3 := t2 * t

			var pt := 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)

			out.append(pt)

	out.append(ctrl[n - 1])
	return out


func get_stream_points() -> PackedVector2Array:
	return _stream_pts


func get_river_center_x(z: float) -> float:
	var bend := 0.0

	if z < -160.0:
		bend = 70.0 * _smoothstep(160.0, 700.0, -z)
	elif z > 160.0:
		bend = -70.0 * _smoothstep(160.0, 700.0, z)

	return 20.0 - 0.55 * z + 16.0 * sin(z * 0.021) + bend


func get_river_water_y(z: float) -> float:
	return -0.012 * (z + 16.0)


func get_river_distance(x: float, z: float) -> float:
	var cx := get_river_center_x(z)
	var dx_dz := -0.55 + 16.0 * 0.021 * cos(z * 0.021)
	var cos_ang := 1.0 / sqrt(1.0 + dx_dz * dx_dz)
	return absf(x - cx) * cos_ang


func _polyline_dist(p: Vector2, pts: PackedVector2Array) -> Dictionary:
	var best_d2 := 1.0e12
	var best_t := 0.0
	var best_proj := p

	if pts.size() < 2:
		return {"dist": 1.0e6, "t": 0.0, "proj": p}

	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var ab2 := ab.length_squared()
		var t := 0.0

		if ab2 > 0.0001:
			t = clampf((p - a).dot(ab) / ab2, 0.0, 1.0)

		var proj := a + ab * t
		var d2 := p.distance_squared_to(proj)

		if d2 < best_d2:
			best_d2 = d2
			best_t = (float(i) + t) / float(pts.size() - 1)
			best_proj = proj

	return {
		"dist": sqrt(best_d2),
		"t": best_t,
		"proj": best_proj
	}


func _nearest_path_info(
	x: float,
	z: float,
	main_path: PackedVector2Array,
	extra_paths: Array[PackedVector2Array]
) -> Dictionary:
	var p := Vector2(x, z)
	var best := _polyline_dist(p, main_path)

	for path in extra_paths:
		var candidate := _polyline_dist(p, path)
		if float(candidate["dist"]) < float(best["dist"]):
			best = candidate

	return best


func get_road_info(x: float, z: float) -> Dictionary:
	return _nearest_path_info(x, z, _road_pts, _extra_road_pts)


func get_trail_info(x: float, z: float) -> Dictionary:
	return _nearest_path_info(x, z, _trail_pts, _extra_trail_pts)


func get_stream_info(x: float, z: float) -> Dictionary:
	return _polyline_dist(Vector2(x, z), _stream_pts)


func _s4_site_weight(x: float, z: float, site: Dictionary) -> float:
	var c: Vector2 = site["c"]
	var d := Vector2(x - c.x, z - c.y).length()
	return 1.0 - _smoothstep(site["r"], site["r"] + site["blend"], d)


func _s4_meadow_weight(x: float, z: float) -> float:
	var w := 0.0
	for site in S4_SITES:
		w = maxf(w, _s4_site_weight(x, z, site) * 0.92)
	return w


func _s4_corridor_weight(x: float, z: float) -> float:
	var w := 0.0
	for c in S4_CORRIDORS:
		var a: Vector2 = c["a"]
		var b: Vector2 = c["b"]
		var ab := b - a
		var t := clampf(Vector2(x - a.x, z - a.y).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var p := a + ab * t
		var d := Vector2(x - p.x, z - p.y).length()
		w = maxf(w, 1.0 - _smoothstep(c["w"], c["w"] + c["blend"], d))
	return w


func _s4_corridor_height(x: float, z: float, h: float) -> float:
	for c in S4_CORRIDORS:
		var a: Vector2 = c["a"]
		var b: Vector2 = c["b"]
		var ab := b - a
		var t := clampf(Vector2(x - a.x, z - a.y).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var p := a + ab * t
		var d := Vector2(x - p.x, z - p.y).length()
		var w := 1.0 - _smoothstep(c["w"], c["w"] + c["blend"], d)
		if w > 0.0:
			h = lerpf(h, lerpf(c["ha"], c["hb"], t), w)
	return h


func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf(
		(x - edge0) / maxf(edge1 - edge0, 0.0001),
		0.0,
		1.0
	)
	return t * t * (3.0 - 2.0 * t)


func _base_mountain_height(x: float, z: float) -> float:
	var n1 := _noise_macro.get_noise_2d(x, z)
	var n2 := _noise_detail.get_noise_2d(x, z)
	var nr := _noise_ridge.get_noise_2d(x, z)

	var dist_center := Vector2(x * 0.92, z).length()

	var valley_bowl := pow(
		_smoothstep(38.0, 650.0, dist_center),
		1.55
	) * 112.0

	var hill_undulation := (
		(n1 * 0.5 + 0.5) * 19.0 *
		_smoothstep(18.0, 180.0, dist_center)
	) + n2 * 2.0

	var ridge_peaks := (
		maxf(0.0, nr) * 46.0 *
		_smoothstep(115.0, 480.0, dist_center)
	)

	# Northwest waterfall cliff shelf.
	var nw_dist := Vector2(x + 84.0, z + 104.0).length()
	var nw_shelf := (
		1.0 - _smoothstep(18.0, 100.0, nw_dist)
	) * 18.0

	# Higher alpine ridges in the southeast.
	var alpine_dist := Vector2(x - 360.0, z - 290.0).length()
	var alpine_rise := (
		1.0 - _smoothstep(70.0, 390.0, alpine_dist)
	) * 32.0

	return (
		2.4 +
		valley_bowl +
		hill_undulation +
		ridge_peaks +
		nw_shelf +
		alpine_rise
	)


func get_height(x: float, z: float) -> float:
	var h := _base_mountain_height(x, z)

	# STAGE 4: cut a flat bench under each outer region, then grade the passes.
	for site in S4_SITES:
		var s4_d: Vector2 = site["c"]
		var s4_w := _s4_site_weight(x, z, site)
		if s4_w > 0.0:
			h = lerpf(h, site["h"], s4_w)
	h = _s4_corridor_height(x, z, h)

	# Central village terrace.
	var v_dist := Vector2(
		x - VILLAGE_CENTER.x,
		z - VILLAGE_CENTER.y
	).length()

	var v_flat := 1.0 - _smoothstep(22.0, 40.0, v_dist)
	h = lerpf(h, VILLAGE_ELEV, v_flat)

	var r_dist := get_river_distance(x, z)
	var road_info := get_road_info(x, z)
	var road_d: float = road_info["dist"]

	# Graded roads, excluding the river channel.
	if road_d < 8.0 and r_dist > 10.5:
		var road_blend := (
			1.0 - _smoothstep(2.4, 8.0, road_d)
		) * 0.72

		# `h` is base + village flatten at this point — identical to the old
		# expression in Stage 3.2, but it also carries the Stage 4 benches.
		var road_target := h
		road_target = lerpf(road_target, VILLAGE_ELEV, v_flat)

		var bridge_d := Vector2(
			x - BRIDGE_CENTER.x,
			z - BRIDGE_CENTER.y
		).length()

		if bridge_d < 20.0:
			var bank_target := 1.48 if r_dist > 9.5 else 0.6
			road_target = lerpf(
				road_target,
				bank_target,
				1.0 - _smoothstep(12.0, 20.0, bridge_d)
			)

		h = lerpf(h, road_target, road_blend)

	# Main river valley and bed.
	if r_dist < 31.0:
		var water_y := get_river_water_y(z)
		var bank_h := water_y + 1.45
		var bed_h := water_y - 1.65
		var river_h := h

		if r_dist < 6.8:
			var deep_t := 1.0 - _smoothstep(1.5, 6.8, r_dist)
			river_h = lerpf(water_y - 0.55, bed_h, deep_t)

		elif r_dist < 15.5:
			var shore := lerpf(
				water_y - 0.55,
				bank_h,
				_smoothstep(6.8, 11.8, r_dist)
			)
			var valley_t := _smoothstep(11.8, 15.5, r_dist) * 0.28
			river_h = lerpf(shore, h, valley_t)

		else:
			var wide_t := _smoothstep(15.5, 31.0, r_dist)
			river_h = lerpf(
				bank_h + (h - bank_h) * 0.30,
				h,
				wide_t
			)

		h = river_h

	# Mountain stream bed.
	var st_info := get_stream_info(x, z)
	var st_d: float = st_info["dist"]

	if st_d < 6.8 and r_dist > 8.0:
		var proj: Vector2 = st_info["proj"]
		var center_base := _base_mountain_height(proj.x, proj.y)
		for s4s in S4_SITES:
			var s4sw := _s4_site_weight(proj.x, proj.y, s4s)
			if s4sw > 0.0:
				center_base = lerpf(center_base, s4s["h"], s4sw)
		center_base = _s4_corridor_height(proj.x, proj.y, center_base)

		var v_flat_p := 1.0 - _smoothstep(
			22.0,
			40.0,
			Vector2(
				proj.x - VILLAGE_CENTER.x,
				proj.y - VILLAGE_CENTER.y
			).length()
		)

		center_base = lerpf(center_base, VILLAGE_ELEV, v_flat_p)

		var bed_target := center_base - 1.10
		var bank_target := center_base + 0.50

		var profile := lerpf(
			bed_target,
			bank_target,
			_smoothstep(2.4, 4.8, st_d)
		)

		var blend_out := 1.0 - _smoothstep(3.8, 6.8, st_d)
		h = lerpf(h, profile, blend_out)

	return h


func get_slope_deg(x: float, z: float) -> float:
	var eps := 1.2

	var hx1 := get_height(x + eps, z)
	var hx0 := get_height(x - eps, z)
	var hz1 := get_height(x, z + eps)
	var hz0 := get_height(x, z - eps)

	var dx := (hx1 - hx0) / (2.0 * eps)
	var dz := (hz1 - hz0) / (2.0 * eps)

	var n := Vector3(-dx, 1.0, -dz).normalized()
	return rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))


func get_splat_weights(x: float, z: float) -> Color:
	# R = road / trail / gravel
	# G = forest floor
	# B = limestone rock

	var road_d: float = get_road_info(x, z)["dist"]
	var trail_d: float = get_trail_info(x, z)["dist"]
	var river_d := get_river_distance(x, z)
	var stream_d: float = get_stream_info(x, z)["dist"]

	var w_road := maxf(
		1.0 - _smoothstep(1.9, 3.6, road_d),
		(1.0 - _smoothstep(0.9, 2.0, trail_d)) * 0.85
	)

	if river_d < 11.0 or stream_d < 3.0:
		w_road = maxf(
			w_road,
			maxf(
				1.0 - _smoothstep(7.5, 11.2, river_d),
				1.0 - _smoothstep(1.5, 3.0, stream_d)
			)
		)

	var h := get_height(x, z)
	var dist_c := Vector2(x, z).length()

	var n_bio := (
		_noise_detail.get_noise_2d(
			x * 0.45 + 120.0,
			z * 0.45 - 80.0
		) * 0.5 + 0.5
	)

	# POPRAVKA: _smoothstep(24,52,dist_c) je bio previsok prag -> sumska
	# podloga (braon, RGB 68/55/38) je pojela travu na velikim povrsinama.
	var w_forest := (
		_smoothstep(6.0, 16.0, h) *
		(1.0 - _smoothstep(34.0, 58.0, h)) *
		_smoothstep(55.0, 110.0, dist_c)
	)

	w_forest = clampf(
		w_forest * (0.45 + 0.55 * n_bio),
		0.0,
		1.0
	)

	if river_d < 13.0:
		w_forest *= _smoothstep(9.0, 13.0, river_d)

	# STAGE 4: region benches read as clearings, not bare limestone; the
	# connector passes read as graded tracks.
	var s4_meadow := _s4_meadow_weight(x, z)
	var s4_track := _s4_corridor_weight(x, z)

	var w_rock := _smoothstep(26.0, 52.0, h) * (1.0 - s4_meadow)
	# POPRAVKA: s4_track je bio *0.9 pa se cijela ravan (spawn, doline, sve
	# izmedju regiona) bojila kao makadam -> teren je izgledao braon/blatnjav
	# i trava je bila rijetka (road_w istisne travu u shaderu).
	# Sada je track samo UZAK put: 0.85 na sredini, brzo pada na 0.
	w_road = maxf(w_road, clampf(s4_track * 1.6, 0.0, 1.0) * 0.85)

	if Vector2(x + 76.0, z + 96.0).length() < 26.0:
		w_rock = maxf(w_rock, 0.75)

	return Color(
		clampf(w_road, 0.0, 1.0),
		clampf(w_forest, 0.0, 1.0),
		clampf(w_rock, 0.0, 1.0),
		1.0
	)


func is_forest_zone(x: float, z: float) -> bool:
	if Vector2(
		x - VILLAGE_CENTER.x,
		z - VILLAGE_CENTER.y
	).length() < 34.0:
		return false

	if get_road_info(x, z)["dist"] < 6.5:
		return false

	if get_trail_info(x, z)["dist"] < 3.8:
		return false

	if get_river_distance(x, z) < 12.5:
		return false

	if get_stream_info(x, z)["dist"] < 4.5:
		return false

	var h := get_height(x, z)

	if h < 3.0 or h > 75.0:
		return false

	if get_slope_deg(x, z) > 33.0:
		return false

	return true
