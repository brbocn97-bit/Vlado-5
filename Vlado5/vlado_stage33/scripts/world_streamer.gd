
extends Node
## NOTE: registered as the "WorldStreamer" autoload in project.godot.
## A class_name here would collide with the singleton name, so references use
## the global autoload identifier instead.

## Stage 4 upgrade of the Stage 3.2 WorldStreamer.
##
## The Stage 3 version could register chunks, but nothing ever registered —
## it was dead code. Stage 4 uses it for two things:
##   1. Region streaming (six WorldRegion nodes, ACTIVE / MID / FAR tiers).
##   2. Backwards-compatible chunk registration for the Stage 3.2 terrain grid.
##
## Radii follow the Stage 4 plan: active <= 280 m, mid <= 520 m, and a 420 m
## hysteresis reload so regions cannot pop-thrash at the boundary.

signal chunk_tier_changed(chunk: Node3D, tier: int)
signal region_state_changed(region: Node3D, state: int)
signal active_region_changed(region: Node3D)

enum ChunkTier { NEAR, MID, FAR }

const ACTIVE_RADIUS := 280.0
const MID_RADIUS := 520.0
const RELOAD_RADIUS := 420.0

@export_group("Player")
@export var player_path: NodePath = NodePath("../VladoPlayer")

@export_group("Streaming")
@export var update_interval: float = 0.25
@export var near_distance: float = 280.0
@export var mid_distance: float = 520.0
@export var hysteresis: float = 40.0
@export var hide_far_chunks: bool = false

var player: Node3D
var registered_chunks: Array[Dictionary] = []
var registered_regions: Array[Node] = []
var current_tiers: Dictionary = {}
var region_states: Dictionary = {}
var current_region: Node = null
var update_timer: float = 0.0


func _ready() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as Node3D
	if near_distance < 0.0:
		near_distance = 0.0
	if mid_distance <= near_distance:
		mid_distance = near_distance + 100.0
	update_timer = update_interval
	process_mode = Node.PROCESS_MODE_ALWAYS


# ------------------------------------------------------------------ regions
func register_region(region: Node) -> void:
	if region == null or registered_regions.has(region):
		return
	registered_regions.append(region)
	region_states[region.get_instance_id()] = WorldRegion.FAR


func unregister_region(region: Node) -> void:
	registered_regions.erase(region)
	region_states.erase(region.get_instance_id())


func get_active_region() -> Node:
	return current_region


func region_state_label(state: int) -> String:
	return ["ACTIVE", "MID", "FAR"][state] if state >= 0 and state <= 2 else "?"


## Force a refresh after teleports / scene load.
func refresh_now() -> void:
	if is_instance_valid(player):
		_update_regions(player.global_position)
		_update_chunks()
		update_timer = 0.0


# ------------------------------------------------------------------- chunks
func register_chunk(chunk: Node3D, center: Vector3, half_extents: Vector2) -> void:
	if chunk == null:
		return
	for entry in registered_chunks:
		if entry["node"] == chunk:
			return
	registered_chunks.append({
		"node": chunk,
		"center": center,
		"half_extents": half_extents,
		"tier": ChunkTier.NEAR,
	})
	current_tiers[chunk.get_instance_id()] = ChunkTier.NEAR


func unregister_chunk(chunk: Node3D) -> void:
	if chunk == null:
		return
	for i in range(registered_chunks.size() - 1, -1, -1):
		if registered_chunks[i]["node"] == chunk:
			registered_chunks.remove_at(i)
	current_tiers.erase(chunk.get_instance_id())


func set_player(new_player: Node3D) -> void:
	player = new_player


func get_chunk_count() -> int:
	return registered_chunks.size()

func get_near_count() -> int:
	return _count_tier(ChunkTier.NEAR)

func get_mid_count() -> int:
	return _count_tier(ChunkTier.MID)

func get_far_count() -> int:
	return _count_tier(ChunkTier.FAR)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	update_timer += delta
	if update_timer < update_interval:
		return
	update_timer = 0.0
	_update_regions(player.global_position)
	_update_chunks()


# ------------------------------------------------------------------ region LOD
func _update_regions(pos: Vector3) -> void:
	var p2 := Vector2(pos.x, pos.z)
	for region in registered_regions:
		if not is_instance_valid(region):
			continue
		var rid: String = region.region_id
		var data := RegionData.get_region(rid)
		if data.is_empty():
			continue
		var dist := RegionData.distance_to_bounds(data, p2)
		var prev: int = region_states.get(region.get_instance_id(), WorldRegion.FAR)
		var next := prev

		if dist <= ACTIVE_RADIUS:
			next = WorldRegion.ACTIVE
		elif dist <= MID_RADIUS:
			next = WorldRegion.MID
		else:
			next = WorldRegion.FAR
		# hysteresis: a FAR region only wakes at RELOAD_RADIUS
		if prev == WorldRegion.FAR and dist > RELOAD_RADIUS:
			next = WorldRegion.FAR
		elif prev == WorldRegion.FAR and dist <= RELOAD_RADIUS:
			next = WorldRegion.MID

		if next != prev:
			region_states[region.get_instance_id()] = next
			region.set_stream_state(next)
			region_state_changed.emit(region, next)

	# inside-region detection for the HUD banner
	var inside := RegionData.region_at(p2)
	if not inside.is_empty():
		var wanted: String = inside["id"]
		for region in registered_regions:
			if is_instance_valid(region) and region.region_id == wanted and region != current_region:
				current_region = region
				active_region_changed.emit(region)
				break


func _update_chunks() -> void:
	var pos := player.global_position
	for entry in registered_chunks:
		var chunk: Node3D = entry["node"]
		if not is_instance_valid(chunk):
			continue
		var dist := _distance_to_chunk(pos, entry["center"], entry["half_extents"])
		var old_tier: int = entry["tier"]
		var new_tier := _calculate_tier(dist, old_tier)
		if new_tier != old_tier:
			entry["tier"] = new_tier
			current_tiers[chunk.get_instance_id()] = new_tier
			_apply_tier(chunk, new_tier)
			chunk_tier_changed.emit(chunk, new_tier)


func _calculate_tier(distance: float, old_tier: int) -> int:
	var margin := maxf(hysteresis, 0.0)
	match old_tier:
		ChunkTier.NEAR:
			if distance > near_distance + margin:
				return ChunkTier.FAR if distance > mid_distance + margin else ChunkTier.MID
			return ChunkTier.NEAR
		ChunkTier.MID:
			if distance < near_distance - margin:
				return ChunkTier.NEAR
			if distance > mid_distance + margin:
				return ChunkTier.FAR
			return ChunkTier.MID
		ChunkTier.FAR:
			if distance < near_distance - margin:
				return ChunkTier.NEAR
			if distance < mid_distance - margin:
				return ChunkTier.MID
			return ChunkTier.FAR
	return ChunkTier.NEAR


func _distance_to_chunk(point: Vector3, center: Vector3, half_extents: Vector2) -> float:
	var cx := clampf(point.x, center.x - half_extents.x, center.x + half_extents.x)
	var cz := clampf(point.z, center.z - half_extents.y, center.z + half_extents.y)
	return Vector2(point.x - cx, point.z - cz).length()


func _apply_tier(chunk: Node3D, tier: int) -> void:
	# Collision stays on: terrain must never let the player fall through.
	chunk.visible = not (tier == ChunkTier.FAR and hide_far_chunks)


func _count_tier(tier: int) -> int:
	var count := 0
	for entry in registered_chunks:
		if entry["tier"] == tier:
			count += 1
	return count


## Compact status block for the Stage 4 debug panel.
func status_lines() -> Array[String]:
	var out: Array[String] = []
	for r in registered_regions:
		if not is_instance_valid(r):
			continue
		var st: int = region_states.get(r.get_instance_id(), WorldRegion.FAR)
		var data := RegionData.get_region(r.region_id)
		out.append("%-26s %s" % [data.get("subtitle", r.region_id), region_state_label(st)])
	return out
