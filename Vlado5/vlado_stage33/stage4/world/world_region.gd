class_name WorldRegion
extends Node3D
## WorldRegion — base for the six Stage 4 regions, driven by the Stage 3.2
## WorldStreamer (which was shipped but never wired up).
##
## Stream states:
##   ACTIVE  region detail, interiors, clutter, actors all live
##   MID     landmarks only (distant buildings), interiors/clutter/actors asleep
##   FAR     landmark group hidden; regions wake again at <= 420 m (hysteresis)

const ACTIVE := 0
const MID := 1
const FAR := 2

var region_id := ""
var focus_point := Vector2.ZERO   ## main landmark, used by debug teleports
var landmroot: Node3D
var detroot: Node3D
var interior_root: Node3D
var actor_root: Node3D
var terrain_data: MontenegroTerrainData = null
var player: Node3D = null
var state := FAR
var _built := false
var enemy_spawner: EnemySpawner = null


func _ready() -> void:
	if landmroot == null:
		landmroot = Node3D.new()
		landmroot.name = "Landmarks"
		add_child(landmroot)
		detroot = Node3D.new()
		detroot.name = "Detail"
		add_child(detroot)
		interior_root = Node3D.new()
		interior_root.name = "Interiors"
		add_child(interior_root)
		actor_root = Node3D.new()
		actor_root.name = "Actors"
		add_child(actor_root)
	if not _built:
		_built = true
		build()
		_enable_garrison()
	set_stream_state(FAR)


## Override in region scripts.
func build() -> void:
	pass


func set_stream_state(new_state: int) -> void:
	state = new_state
	if landmroot == null:
		return
	var is_active := new_state == ACTIVE
	landmroot.visible = new_state != FAR
	detroot.visible = is_active
	interior_root.visible = is_active
	actor_root.visible = is_active
	detroot.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	interior_root.process_mode = Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	if enemy_spawner and is_instance_valid(enemy_spawner):
		enemy_spawner.set_active(is_active)
	var actor_mode := Node.PROCESS_MODE_INHERIT if is_active else Node.PROCESS_MODE_DISABLED
	for a in actor_root.get_children():
		a.process_mode = actor_mode


func add_landmark(n: Node3D) -> Node3D:
	landmroot.add_child(n)
	return n

func add_detail(n: Node3D) -> Node3D:
	detroot.add_child(n)
	return n

func add_interior(n: Node3D) -> Node3D:
	interior_root.add_child(n)
	return n

func add_actor(n: Node3D) -> Node3D:
	actor_root.add_child(n)
	return n


## Place a node on the baseline terrain.
##
## POPRAVLJENO (defekt #6, lebdece gajbe):
## Ako je `sink == 0.0`, automatski se dno vizuelnog mesha poravna sa tlom.
## Prije je pozivalac morao rucno dodavati `position.y += visina/2`, i to je
## cesto promasivalo (npr. gajbe na Axis punktu: 0.22 umjesto 0.22+...),
## pa su gajbe lebdjele ili bile do pola u zemlji.
##
## `sink > 0` ostaje staro ponasanje (namjerno kopanje u teren: ograde, kolce).
func place(n: Node3D, x: float, z: float, sink: float = 0.18) -> Node3D:
	var y := 0.0
	if terrain_data:
		y = terrain_data.get_height(x, z)
	n.position = Vector3(x, y - sink, z)
	if is_zero_approx(sink):
		# poravnaj DNO mesha na y (ne centar) — samo za male objekte
		var box := _node_local_aabb(n)
		if box.size != Vector3.ZERO and box.size.length() < 6.0:
			n.position.y = y - box.position.y
	return n


## Lokalni AABB celog podstabla (akumulira transforme kroz sve nivoe).
func _node_local_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[n, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var c: Node = item[0]
		var xf: Transform3D = item[1]
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			var b: AABB = xf * (c as MeshInstance3D).get_aabb()
			out = b if first else out.merge(b)
			first = false
		for ch in c.get_children():
			var cxf: Transform3D = xf
			if ch is Node3D:
				cxf = xf * (ch as Node3D).transform
			stack.append([ch, cxf])
	return out


## Stage 4 enemies: every region gets a garrison node. It builds nothing until
## the region first turns ACTIVE, which keeps the initial load cheap.
func _enable_garrison() -> void:
	if enemy_spawner != null:
		return
	enemy_spawner = EnemySpawner.new()
	enemy_spawner.name = "Garrison"
	add_child(enemy_spawner)
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	enemy_spawner.setup(self, terrain_data, p)
