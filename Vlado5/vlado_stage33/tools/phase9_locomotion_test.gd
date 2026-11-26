extends SceneTree

var bad := 0
var player: Node

func _init() -> void:
	call_deferred("_run")

func _physics_frames(count: int) -> void:
	for _i in count:
		await physics_frame

func _check(label: String, condition: bool, details: String) -> void:
	print("PHASE9_LOCO %s %s ok=%s" % [label, details, condition])
	if not condition:
		bad += 1

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	world.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000.0, 0.5, 1000.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.25
	floor_body.add_child(floor_shape)

	player = load("res://characters/vlado/vlado_character.tscn").instantiate() as Node
	world.add_child(player)
	await _physics_frames(20)
	_check("grounded", player.is_on_floor(), "y=%.3f" % player.global_position.y)

	player.set_touch_move_vector(Vector2(0, 1))
	await _physics_frames(120)
	_check("walk", player.current_locomotion_state == "Walking", "state=%s speed=%.2f" % [player.current_locomotion_state, player.current_horizontal_speed])
	_check("walk_speed", absf(player.current_horizontal_speed-player.walk_speed) < 0.18, "actual=%.2f target=%.2f" % [player.current_horizontal_speed, player.walk_speed])

	player.set_touch_move_vector(Vector2.ZERO)
	await _physics_frames(55)
	_check("stop", player.current_locomotion_state == "Idle" and player.current_horizontal_speed < 0.14, "state=%s speed=%.2f" % [player.current_locomotion_state, player.current_horizontal_speed])

	player.toggle_run()
	player.set_touch_move_vector(Vector2(0, 1))
	await _physics_frames(130)
	_check("run", player.current_locomotion_state == "Running", "state=%s speed=%.2f" % [player.current_locomotion_state, player.current_horizontal_speed])
	_check("run_speed", absf(player.current_horizontal_speed-player.run_speed) < 0.22, "actual=%.2f target=%.2f" % [player.current_horizontal_speed, player.run_speed])

	player.toggle_sprint()
	await _physics_frames(150)
	_check("sprint", player.current_locomotion_state == "Sprinting", "state=%s speed=%.2f stamina=%.1f" % [player.current_locomotion_state, player.current_horizontal_speed, player.stamina])

	player.set_touch_move_vector(Vector2.ZERO)
	await _physics_frames(55)
	player.toggle_crouch()
	player.set_touch_move_vector(Vector2(0, 1))
	await _physics_frames(100)
	_check("crouch", player.current_locomotion_state == "CrouchWalk", "state=%s speed=%.2f" % [player.current_locomotion_state, player.current_horizontal_speed])
	_check("crouch_speed", absf(player.current_horizontal_speed-player.crouch_speed) < 0.18, "actual=%.2f target=%.2f" % [player.current_horizontal_speed, player.crouch_speed])

	player.set_touch_move_vector(Vector2.ZERO)
	await _physics_frames(40)
	player.toggle_crouch()
	player.request_jump()
	var saw_air := false
	var saw_land := false
	for _i in 160:
		await physics_frame
		if player.current_locomotion_state in ["JumpStart", "Jumping"]:
			saw_air = true
		if saw_air and player.current_locomotion_state == "Landing":
			saw_land = true
	_check("jump_air", saw_air, "state_seen=%s" % saw_air)
	_check("jump_land", saw_land, "landing_seen=%s final=%s" % [saw_land, player.current_locomotion_state])

	print("PHASE9_LOCOMOTION_DONE bad=%d" % bad)
	quit(0 if bad == 0 else 1)
