class_name Stage33Bootstrap
extends Node
## Stage33Bootstrap — mounts the Stage 3.3 arsenal without touching Stage 3.2.
##
## Adds, as children of the player:
##   · WeaponArsenal   (weapon list, models, firing for captured guns)
##   · ArsenalHUD      (weapon readout + pickup prompt)
## and scatters a few weapon pickups near the spawn so the new guns can be
## tested immediately, plus the world placement hooks Stage 4 uses later.

@export var debug_pickups := false
@export var debug_fps_rot := false
var swap_key := KEY_Q
@export var reload_key := KEY_R

var player: PlayerController
var arsenal: WeaponArsenal
var hud: ArsenalHUD
var pickups: Array[WeaponPickup] = []
var _mouse_held := false
var _mobile_controls: MobileControls


func _ready() -> void:
	call_deferred("_start")


func _start() -> void:
	var world := get_parent()
	await get_tree().process_frame
	await get_tree().process_frame

	player = world.get_node_or_null("VladoPlayer") as PlayerController
	if player == null:
		player = world.find_child("VladoPlayer", true, false) as PlayerController
	if player == null:
		push_error("Stage33: VladoPlayer not found")
		return

	arsenal = WeaponArsenal.new()
	arsenal.name = "WeaponArsenal"
	player.add_child(arsenal)

	hud = ArsenalHUD.new()
	hud.name = "ArsenalHUD"
	world.add_child(hud)
	hud.bind(arsenal)

	arsenal.weapon_changed.connect(_on_weapon_changed)
	arsenal.show_weapon(WeaponArsenal.SLOT_GASSER, true)
	_mobile_controls = world.get_node_or_null("MobileControls") as MobileControls

	if debug_pickups:
		_spawn_debug_pickups(world)

	print("[Stage33] arsenal online — %d weapons defined, %d owned" % [
		arsenal.weapons.size(), arsenal.owned.size()])


func _on_weapon_changed(d: WeaponDef) -> void:
	if hud and d:
		hud.toast("U ruci: " + d.display_name)


## Two pickups on the spawn road so the arsenal can be exercised at once.
func _spawn_debug_pickups(world: Node) -> void:
	# in front of the spawn camera (which looks toward -Z)
	# ~6 m dead ahead of the spawn point, offset left and right so both read
	# clearly as a pair on the approach
	# Right next to the spawn so the arsenal can be exercised without walking.
	# === POPRAVKA v17 — GRUPA E ===
	# v16: dva pickupa na 1.8 m razmaka -> iz ugla kamere izgledaju kao DVA
	# PRSTENA oko jednog oruzja (korisnik je to prijavio kao gresku).
	# Za testiranje ostaje SAMO JEDAN pickup. Ostali se vracaju kad se potvrdi
	# da sistem radi, sa razmakom od najmanje 4 m.
	var specs := [
		{"id": "mp40", "pos": Vector3(-5.9, 0, 7.6)},
		{"id": "mauser_98", "pos": Vector3(1.8, 0, 7.6)},
	]
	var terrain = world.get("terrain_data")
	for s in specs:
		var p := WeaponPickup.new()
		p.name = "Pickup_" + str(s["id"])
		p.weapon_id = s["id"]
		p.arsenal = arsenal
		p.hud = hud
		var pos: Vector3 = s["pos"]
		var y := 0.0
		if terrain and terrain.has_method("get_height"):
			y = terrain.get_height(pos.x, pos.z)
		p.position = Vector3(pos.x, y + 0.05, pos.z)
		world.add_child(p)
		pickups.append(p)
		print("[Stage33] pickup %s at %s (y=%.2f)" % [s["id"], str(p.global_position), y])


# ------------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == swap_key and arsenal and arsenal.owned.size() > 1:
			arsenal.next_weapon()
			get_viewport().set_input_as_handled()
		elif event.keycode == reload_key and arsenal and arsenal.active != WeaponArsenal.SLOT_M48:
			arsenal.reload()
			get_viewport().set_input_as_handled()
		elif debug_fps_rot and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			# debug-only: six candidate orientations for the FPS holder
			var presets := [
				Vector3.ZERO, Vector3(0, 90, 0), Vector3(90, 0, 0),
				Vector3(0, 0, 90), Vector3(180, 0, 0), Vector3(0, 180, 0),
			]
			var idx: int = event.keycode - KEY_1
			var rig := player.get_node_or_null("FirstPersonRig")
			if rig and rig.has_method("fp_debug_rot"):
				rig.fp_debug_rot(presets[idx])
			get_viewport().set_input_as_handled()
	# === POPRAVKA v17 ===
	# Ovdje je stajalo `_mouse_held = event.pressed` za SVAKI dodir ekrana i
	# svaki lijevi klik. Posljedica: svaki dodir dzojstika za hod (ili bilo
	# gdje po ekranu) drzao je okidac pritisnutim -> MG42 je pucao sam od
	# sebe dok hodas. Okidac sada ide ISKLJUCIVO preko dugmeta "FIRE"
	# (mobile_controls.fire_pressed -> debug_hud), a ovo je samo rezerva za
	# fizicku tastaturu/mis na desktopu.
	elif event is InputEventKey and event.keycode == KEY_CTRL and event.echo == false:
		_mouse_held = event.pressed
	# === kraj popravke ===


func _process(_delta: float) -> void:
	if arsenal == null or player == null:
		return
	# Automatic weapons keep firing while the trigger is held. The M48 stays
	# bolt-action and is still driven by its own Stage 3.2 code path.
	var touch_fire := _mobile_controls != null and _mobile_controls.is_fire_held()
	if (_mouse_held or touch_fire) and arsenal.is_automatic():
		arsenal.try_fire(true)
