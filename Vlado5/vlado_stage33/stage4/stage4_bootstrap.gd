class_name Stage4Bootstrap
extends Node
## Stage4Bootstrap — mounts the Stage 4 layer into the Stage 3.2 world.
##
## Drop this node into montenegro_world.tscn (or let Main auto-add it) and it:
##   1. waits for MontenegroWorld._ready() to finish building the baseline
##   2. hands the baseline terrain_data to the Stage 4 terrain-bound props
##   3. instantiates Stage4World (regions, extended river, bridge lamps)
##   4. wires the interaction ray to the player camera
##   5. attaches Stage4HUD next to the existing DebugHUD
##
## Nothing in the Stage 3.2 scripts is modified.

@export var auto_start := true
@export var spawn_region_override := ""   # debug: "Crnca_Village", "PostWar_Checkpoint"...

var world_node: Node3D
var world: Stage4World
var hud: Stage4HUD
var bridge: InteractionBridge


func _ready() -> void:
	if auto_start:
		call_deferred("_start")


func _start() -> void:
	world_node = get_parent() as Node3D
	if world_node == null:
		push_error("Stage4Bootstrap must be a child of MontenegroWorld")
		return

	# 1. wait for the baseline to finish its own _ready
	await world_node.get_tree().process_frame
	await world_node.get_tree().process_frame

	var terrain_data: MontenegroTerrainData = world_node.get("terrain_data") as MontenegroTerrainData
	if terrain_data == null:
		terrain_data = MontenegroTerrainData.new()
		push_warning("Stage4: terrain_data not found on the world node — using a fresh instance.")

	var player: PlayerController = world_node.get_node_or_null("VladoPlayer") as PlayerController
	var camera_rig: PlayerCamera = null
	if player:
		camera_rig = player.get_node_or_null("CameraRig") as PlayerCamera
		if camera_rig == null:
			camera_rig = player.find_child("CameraRig", true, false) as PlayerCamera
	var debug_hud: Node = world_node.get_node_or_null("DebugHUD") as Node

	# 2. Stage 4 HUD
	hud = Stage4HUD.new()
	hud.name = "Stage4HUD"
	world_node.add_child(hud)

	# 3. register the player as "player" group BEFORE world.setup() so EnemySpawner finds it
	if player:
		player.add_to_group("player")

	# 4. Stage 4 world
	world = Stage4World.new()
	world.name = "Stage4World"
	world_node.add_child(world)
	world.setup(terrain_data, player, hud)
	hud.bind_world(world)

	# 5. interaction bridge on the player's camera
	if player and camera_rig:
		bridge = InteractionBridge.new()
		bridge.name = "InteractionBridge"
		world_node.add_child(bridge)
		bridge.setup(player, camera_rig, hud)

	# 6. make sure the STAGE 3.2 streamer knows about the player
	var streamer := get_tree().root.get_node_or_null("WorldStreamer")
	if streamer and player:
		streamer.set_player(player)
		if streamer.has_method("refresh_now"):
			streamer.refresh_now()

	if spawn_region_override != "":
		world.teleport_to_region(spawn_region_override)


	# Native renderer culling for sub-pixel props; no box impostors or watcher nodes.
	var culled_prop_count := LodHelper.apply_to_tree(world, 220.0)
	print("[Stage4] distance culling applied to %d small props (far=220m)" % culled_prop_count)

	var qm := get_tree().root.get_node_or_null("QualityManager")
	if qm and qm.has_method("apply"):
		qm.apply()

	print("[Stage4] world mounted: %d regions, %d clues catalogued" % [
		world.regions.size(), Stage4Ledger.clues_available.size()])


