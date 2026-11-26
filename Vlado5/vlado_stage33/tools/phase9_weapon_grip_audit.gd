extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := load("res://characters/vlado/vlado_character.tscn").instantiate() as PlayerController
	world.add_child(player)
	var arsenal := WeaponArsenal.new()
	arsenal.name = "WeaponArsenal"
	player.add_child(arsenal)
	for _i in 5: await process_frame
	var skel := player.find_child("Skeleton3D", true, false) as Skeleton3D
	var left_idx := skel.find_bone("LeftHand")
	var right_idx := skel.find_bone("RightHand")
	var bad := 0
	for slot in [3,1,2,4,14,19,27,29,30]:
		arsenal.show_weapon(slot, true)
		for _i in 22: await process_frame
		var model: Node3D = arsenal.held.get(slot) as Node3D
		if model == null:
			print("PHASE9_GRIP slot=%d missing_model=true" % slot); bad += 1; continue
		var grip_r := model.find_child("Grip_R", true, false) as Node3D
		var grip_l := model.find_child("Grip_L", true, false) as Node3D
		var rh_world := skel.global_transform * skel.get_bone_global_pose(right_idx).origin
		var lh_world := skel.global_transform * skel.get_bone_global_pose(left_idx).origin
		var dr := grip_r.global_position.distance_to(rh_world) if grip_r else model.global_position.distance_to(rh_world)
		var dl := grip_l.global_position.distance_to(lh_world) if grip_l else -1.0
		var def := arsenal.def_for(slot)
		var right_ok := dr < 0.12
		var left_ok := true
		var axis_error := -1.0
		var along := -1.0
		if grip_r and grip_l and def.hold_style in ["rifle","heavy"]:
			var axis := (grip_l.global_position-grip_r.global_position).normalized()
			var to_hand := lh_world-grip_r.global_position
			along = to_hand.dot(axis)
			axis_error = (to_hand-axis*along).length()
			# Ruka smije uhvatiti dalje duž kundaka/cijevi od generičkog Grip_L markera,
			# ali mora ležati na osi oružja i unutar njegove stvarne dužine.
			left_ok = axis_error < 0.08 and along > 0.12 and along < def.target_length_m * 1.05
		print("PHASE9_GRIP slot=%d id=%s style=%s right=%.3f marker_left=%.3f axis_error=%.3f along=%.3f right_ok=%s left_ok=%s" % [slot,def.id,def.hold_style,dr,dl,axis_error,along,right_ok,left_ok])
		if not right_ok or not left_ok: bad += 1
	print("PHASE9_WEAPON_GRIP_DONE bad=%d" % bad)
	quit(0 if bad == 0 else 1)
