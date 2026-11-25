class_name EnemySpawner
extends Node3D
## EnemySpawner — garrisons each region with historical-phase Yugoslav forces.
##
## Placement is data-driven and tied to the region geometry that already
## exists: the checkpoint gets a proper guard rotation around the watchtower and
## barrier, the village gets two men on the street, the hideout gets a patrol
## sweeping the treeline. Soldiers are only spawned when their region becomes
## ACTIVE and are put to sleep when it falls back to MID/FAR — that is the
## "aktivni NPC samo unutar 115 m" requirement from the design plan, expressed
## as region streaming rather than a second distance system.

const MAX_ACTIVE_DISTANCE := 115.0

## id, spawn points, patrol routes (world XZ), and how many to keep alive
const GARRISONS := {
	"Security_Checkpoint": {
		"faction": "ozna",
		"soldiers": [
			{"pos": Vector2(322.0, -104.0), "route": [Vector2(322, -104), Vector2(300, -118), Vector2(286, -104)]},
			{"pos": Vector2(356.0, -76.0), "route": [Vector2(356, -76), Vector2(372, -96), Vector2(352, -112)]},
			{"pos": Vector2(300.0, -80.0), "route": [Vector2(300, -80), Vector2(330, -70), Vector2(348, -86)]},
			{"pos": Vector2(390.0, -120.0), "route": [Vector2(390, -120), Vector2(368, -138), Vector2(398, -142)]},
		],
	},
	"Crnca_Village": {
		"faction": "partizan",
		"soldiers": [
			{"pos": Vector2(-322.0, 6.0), "route": [Vector2(-322, 6), Vector2(-300, 18), Vector2(-330, 30)]},
			{"pos": Vector2(-368.0, -6.0), "route": [Vector2(-368, -6), Vector2(-390, 12), Vector2(-366, 26)]},
		],
	},
	"Durmitor_Forest_Hideout": {
		"faction": "udba",
		"soldiers": [
			{"pos": Vector2(-262.0, -352.0), "route": [Vector2(-262, -352), Vector2(-240, -336), Vector2(-220, -350)]},
			{"pos": Vector2(-228.0, -318.0), "route": [Vector2(-228, -318), Vector2(-250, -300), Vector2(-272, -316)]},
		],
	},
	"Krupa_Canyon_Crossings": {
		"faction": "ozna",
		"soldiers": [
			{"pos": Vector2(56.0, 258.0), "route": [Vector2(56, 258), Vector2(80, 272), Vector2(96, 254)]},
		],
	},
	"Lovcen_High_Peaks": {
		"faction": "udba",
		"soldiers": [
			{"pos": Vector2(376.0, 306.0), "route": [Vector2(376, 306), Vector2(400, 322), Vector2(390, 344)]},
		],
	},
}

var region: WorldRegion
var terrain_data: MontenegroTerrainData
var soldiers: Array[PostWarEnemy] = []
var player: PlayerController
var _spawned := false


func setup(p_region: WorldRegion, p_terrain: MontenegroTerrainData, p_player: PlayerController) -> void:
	region = p_region
	terrain_data = p_terrain
	player = p_player


func spawn_garrison() -> void:
	if _spawned or region == null:
		return
	_spawned = true
	var def: Dictionary = GARRISONS.get(region.region_id, {})
	var list: Array = def.get("soldiers", [])
	for e in list:
		var s := PostWarEnemy.new()
		s.faction = def.get("faction", "partizan")
		s.name = "Soldier_%s_%d" % [region.region_id, soldiers.size()]
		s.player = player
		var pos: Vector2 = e["pos"]
		var y: float = terrain_data.get_height(pos.x, pos.y) if terrain_data else 0.0
		s.position = Vector3(pos.x, y + 0.05, pos.y)
		var route: Array[Vector3] = []
		for r in e["route"]:
			var rp: Vector2 = r
			var ry: float = terrain_data.get_height(rp.x, rp.y) if terrain_data else 0.0
			route.append(Vector3(rp.x, ry, rp.y))
		s.set_patrol(route)
		s.died.connect(_on_soldier_died)
		add_child(s)
		soldiers.append(s)
	if not list.is_empty():
		print("[Stage4] garrison %s: %d vojnika" % [region.region_id, soldiers.size()])


func _on_soldier_died(s: PostWarEnemy) -> void:
	Stage4Ledger.report_kill()


## Called by the region when its stream state changes.
func set_active(active: bool) -> void:
	if active:
		spawn_garrison()
	for s in soldiers:
		if is_instance_valid(s) and s.state != PostWarEnemy.State.DEAD:
			s.set_physics_process(active)
			s.visible = active
			s.collision_layer = 4 if active else 0


func alive_count() -> int:
	var n := 0
	for s in soldiers:
		if is_instance_valid(s) and s.state != PostWarEnemy.State.DEAD:
			n += 1
	return n


func total_count() -> int:
	return soldiers.size()
