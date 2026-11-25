class_name PostWarEnemy
extends CharacterBody3D
## PostWarEnemy — 1945+ Yugoslav adversary using the existing patrol/vision/combat AI.
##
## Behaviour states:
##   PATROL   walks a route between waypoints, sweeping the head
##   ALERT    stopped, looking at a suspicious point ("Šta je to?")
##   CHASE    runs toward the last known player position
##   COMBAT   in range and line of sight: stops, aims, fires in bursts
##   SEARCH   lost the player: sweeps the last known area, then returns
##   DEAD     ragdoll-lite: falls over, stops processing
##
## Everything is deliberately cheap: one cheap raycast per perception tick
## (10 Hz by default), no navmesh, no pathfinding — waypoints plus direct
## steering, which is correct for the flat Stage 4 region benches.

signal died(soldier: PostWarEnemy)
signal alerted(soldier: PostWarEnemy, player_pos: Vector3)

enum State { PATROL, ALERT, CHASE, COMBAT, SEARCH, DEAD }

# --- perception tuning (metres / seconds)
@export var view_distance := 42.0
@export var view_cone_deg := 110.0
@export var hearing_radius := 18.0
@export var alert_delay := 0.55
@export var search_duration := 9.0
@export var fire_range := 34.0
@export var burst_interval := 2.1         # seconds between bursts
@export var aim_time := 0.9               # telegraph before the first shot
@export var accuracy_deg := 2.4           # spread on each fired round
@export var damage_per_hit := 9.0
@export var move_speed := 1.45
@export var chase_speed := 4.1
@export var max_health := 55.0

var state: State = State.PATROL
var health := 55.0
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var player: PlayerController
var model: PostWarEnemyModel
var faction := "partizan"
var home_position := Vector3.ZERO

var _perception_timer := 0.0
var _state_timer := 0.0
var _burst_timer := 0.0
var _aim_timer := 0.0
var _last_known := Vector3.ZERO
var _has_last_known := false
var _walk_phase := 0.0
var _gravity := 14.2
var _search_sweep := 0.0
var _faction_initialized := false

const GRAVITY := 14.2
const PERCEPTION_HZ := 0.1


func _apply_faction_profile() -> void:
	match faction:
		"partizan":
			view_distance = 34.0
			view_cone_deg = 120.0
			hearing_radius = 22.0
			alert_delay = 0.75
			search_duration = 7.0
			fire_range = 28.0
			burst_interval = 2.4
			damage_per_hit = 8.0
			move_speed = 1.55
			chase_speed = 3.8
			max_health = 50.0
		"ozna":
			view_distance = 48.0
			view_cone_deg = 95.0
			hearing_radius = 26.0
			alert_delay = 0.45
			search_duration = 12.0
			fire_range = 38.0
			burst_interval = 1.75
			accuracy_deg = 1.8
			damage_per_hit = 10.0
			move_speed = 1.65
			chase_speed = 4.4
			max_health = 62.0
		"udba":
			view_distance = 58.0
			view_cone_deg = 82.0
			hearing_radius = 30.0
			alert_delay = 0.30
			search_duration = 16.0
			fire_range = 44.0
			burst_interval = 1.45
			accuracy_deg = 1.35
			damage_per_hit = 11.0
			move_speed = 1.75
			chase_speed = 4.7
			max_health = 68.0
	health = max_health


func _ready() -> void:
	_apply_faction_profile()
	collision_layer = 4          # enemy layer (baseline targets also use it)
	collision_mask = 1
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.80
	cs.shape = cap
	cs.position = Vector3(0, 0.90, 0)
	add_child(cs)

	model = PostWarEnemyModel.new()
	model.faction = faction
	model.name = "Model"
	add_child(model)

	health = max_health
	home_position = global_position
	add_to_group("postwar_enemies")
	add_to_group("enemies")
	if patrol_points.is_empty():
		patrol_points = [global_position]


func set_patrol(points: Array[Vector3]) -> void:
	patrol_points = points
	if not patrol_points.is_empty():
		home_position = patrol_points[0]


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_perception_timer -= delta
	if _perception_timer <= 0.0:
		_perception_timer = PERCEPTION_HZ
		_perceive()

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.ALERT:
			_do_alert(delta)
		State.CHASE:
			_do_chase(delta)
		State.COMBAT:
			_do_combat(delta)
		State.SEARCH:
			_do_search(delta)

	# gravity + move
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_animate(delta)


# ------------------------------------------------------------------ perceive
func _perceive() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as PlayerController
		if player == null:
			return
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > view_distance:
		if state == State.COMBAT or state == State.CHASE:
			_enter_search()
		return

	# is it in front of us?
	var forward := -global_transform.basis.z
	var flat_raw := Vector3(to_player.x, 0, to_player.z)
	if flat_raw.length_squared() > 0.0001:
		var ang := rad_to_deg(forward.angle_to(flat_raw.normalized()))
		if ang > view_cone_deg * 0.5:
			return

	# line of sight
	if not _can_see(player.global_position):
		return

	_last_known = player.global_position
	_has_last_known = true
	if state == State.PATROL or state == State.SEARCH:
		_enter_alert()
	elif state == State.COMBAT:
		if dist > fire_range * 1.15:
			state = State.CHASE


func _can_see(target: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.55, 0)
	var q := PhysicsRayQueryParameters3D.create(from, target + Vector3(0, 1.1, 0), 1)
	var res := space.intersect_ray(q)
	return res.is_empty()


func _enter_alert() -> void:
	state = State.ALERT
	_state_timer = alert_delay
	velocity.x = 0
	velocity.z = 0
	alerted.emit(self, _last_known)
	if faction in ["ozna", "udba"]:
		_alert_nearby()


func _alert_nearby() -> void:
	for n in get_tree().get_nodes_in_group("postwar_enemies"):
		if n == self or not (n is PostWarEnemy):
			continue
		var ally := n as PostWarEnemy
		if not is_instance_valid(ally) or ally.state == State.DEAD:
			continue
		if global_position.distance_to(ally.global_position) <= (42.0 if faction == "udba" else 28.0):
			ally._last_known = _last_known
			ally._has_last_known = true
			if ally.state == State.PATROL or ally.state == State.SEARCH:
				ally.state = State.CHASE


func _enter_search() -> void:
	state = State.SEARCH
	_state_timer = search_duration
	_search_sweep = 0.0


# --------------------------------------------------------------------- states
func _do_patrol(delta: float) -> void:
	if patrol_points.size() <= 1:
		_idle_scan(delta)
		return
	var target := patrol_points[patrol_index]
	var to := target - global_position
	to.y = 0
	if to.length() < 1.2:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		return
	_steer(to.normalized(), move_speed)
	_face(to)
	_walk_phase += delta * move_speed * 3.4


func _do_alert(delta: float) -> void:
	_face(_last_known - global_position)
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.CHASE


func _do_chase(delta: float) -> void:
	if not _has_last_known:
		_enter_search()
		return
	var to := _last_known - global_position
	to.y = 0
	if to.length() < 2.0:
		# reached the spot but no visual contact -> sweep
		if state == State.CHASE:
			state = State.SEARCH
			_state_timer = search_duration
		return
	_steer(to.normalized(), chase_speed)
	_face(to)
	_walk_phase += delta * chase_speed * 2.6
	# arrived at firing range with LOS? engage
	var dist_to_player := global_position.distance_to(_last_known)
	if dist_to_player <= fire_range and _can_see(_last_known):
		state = State.COMBAT
		_aim_timer = aim_time
		_burst_timer = 0.0


func _do_combat(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	if not _has_last_known:
		_enter_search()
		return
	_face(_last_known - global_position)
	var dist := global_position.distance_to(_last_known)
	if dist > fire_range * 1.2 or not _can_see(_last_known):
		state = State.CHASE
		return
	if _aim_timer > 0.0:
		_aim_timer -= delta
		return
	_burst_timer -= delta
	if _burst_timer > 0.0:
		return
	_fire_burst()
	_burst_timer = burst_interval


func _do_search(delta: float) -> void:
	_state_timer -= delta
	_search_sweep += delta
	velocity.x = 0
	velocity.z = 0
	# sweep the head left and right while waiting
	if model:
		model.rotation.y = sin(_search_sweep * 1.6) * 0.7
	if _state_timer <= 0.0:
		if model:
			model.rotation.y = 0.0
		state = State.PATROL
		_has_last_known = false


# ------------------------------------------------------------------- shooting
func _fire_burst() -> void:
	if player == null or not is_instance_valid(player):
		return
	var shots := 3 if randf() < 0.7 else 2
	var muzzle_pos := global_position + Vector3(0, 1.5, 0)
	var target := player.global_position + Vector3(0, 1.1, 0)
	for i in shots:
		var spread := deg_to_rad(accuracy_deg)
		var dir := (target - muzzle_pos).normalized()
		dir += Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
		dir = dir.normalized()
		# line of sight at the moment of firing, so shots do not go through walls
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(muzzle_pos, muzzle_pos + dir * fire_range, 1)
		var res := space.intersect_ray(q)
		var end_pos: Vector3 = res["position"] if not res.is_empty() else muzzle_pos + dir * fire_range
		var hit_dist := muzzle_pos.distance_to(end_pos) if not res.is_empty() else fire_range
		var fx := get_tree().current_scene
		if fx:
			WeaponEffects.spawn_tracer(fx, muzzle_pos, end_pos)
			if not res.is_empty():
				WeaponEffects.spawn_impact(fx, end_pos, res["normal"], "dirt")
		# does the ray hit the player without hitting a closer wall?
		var to_player := (player.global_position + Vector3(0, 1.0, 0)) - muzzle_pos
		var player_dist := to_player.length()
		if player_dist > 0.05 and hit_dist >= player_dist - 0.35 and dir.angle_to(to_player.normalized()) < deg_to_rad(3.0):
			if player.has_method("take_damage"):
				player.take_damage(damage_per_hit)
			elif "health" in player:
				player.health = maxf(0.0, player.health - damage_per_hit)


func take_damage(amount: float) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		_die()
		return
	# being shot is instant knowledge of where the shooter is
	_last_known = player.global_position if player else global_position
	_has_last_known = true
	if state == State.PATROL or state == State.SEARCH:
		state = State.COMBAT
		_aim_timer = 0.35


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	set_physics_process(false)
	# fall over
	if model:
		var tw := create_tween()
		tw.tween_property(model, "rotation_degrees:x", -88.0, 0.55).set_ease(Tween.EASE_OUT)
		model.rotation_degrees.z = randf_range(-12.0, 12.0)
	died.emit(self)


# ------------------------------------------------------------------ utilities
func _steer(dir: Vector3, speed: float) -> void:
	var move_dir := dir.normalized()
	var space := get_world_3d().direct_space_state
	if space:
		var forward_origin := global_position + Vector3(0, 1.0, 0)
		var probe_length := 1.35
		var q := PhysicsRayQueryParameters3D.create(forward_origin, forward_origin + move_dir * probe_length, 1)
		q.exclude = [get_rid()]
		if not space.intersect_ray(q).is_empty():
			var right := Vector3(-move_dir.z, 0, move_dir.x)
			var left := -right
			var qr := PhysicsRayQueryParameters3D.create(forward_origin, forward_origin + right * probe_length, 1)
			qr.exclude = [get_rid()]
			var ql := PhysicsRayQueryParameters3D.create(forward_origin, forward_origin + left * probe_length, 1)
			ql.exclude = [get_rid()]
			var right_hit := space.intersect_ray(qr)
			var left_hit := space.intersect_ray(ql)
			if left_hit.is_empty() and not right_hit.is_empty():
				move_dir = left
			elif right_hit.is_empty():
				move_dir = right
			else:
				move_dir = move_dir.slide(Vector3.UP)
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed


func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, 0, target.z)
	if flat.length() < 0.01:
		return
	var want := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, want, 0.12)


func _idle_scan(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	if model:
		model.rotation.y = sin(Time.get_ticks_msec() * 0.0006) * 0.38


func _animate(delta: float) -> void:
	if model == null:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.15:
		# settle limbs
		if model.left_leg:
			model.left_leg.rotation.x = lerpf(model.left_leg.rotation.x, 0.0, 0.2)
			model.right_leg.rotation.x = lerpf(model.right_leg.rotation.x, 0.0, 0.2)
		if model.left_arm:
			model.left_arm.rotation.x = lerpf(model.left_arm.rotation.x, 0.0, 0.2)
			model.right_arm.rotation.x = lerpf(model.right_arm.rotation.x, 0.0, 0.2)
		return
	var swing := sin(_walk_phase) * 0.62
	if model.left_leg:
		model.left_leg.rotation.x = swing
		model.right_leg.rotation.x = -swing
	if model.left_arm:
		model.left_arm.rotation.x = -swing * 0.55
		model.right_arm.rotation.x = swing * 0.55
	# bobbing torso
	if model.torso:
		model.torso.position.y = 0.92 + absf(sin(_walk_phase * 2.0)) * 0.025


func state_name() -> String:
	return ["PATROL", "ALERT", "CHASE", "COMBAT", "SEARCH", "DEAD"][state]
