class_name PickupStage4
extends Stage4Interactable
## Ammo / medical / bandage pickups that feed the Stage 3.2 WeaponController
## (reserve ammo) and PlayerController (health) APIs.

@export var ammo_amount := 15
@export var heal_amount := 0.0
@export var visual := "ammo"     # ammo | medkit | bandage


func _ready() -> void:
	kind = Kind.PICKUP_MEDKIT if heal_amount > 0.0 else Kind.PICKUP_AMMO
	super._ready()
	_build()


func _build() -> void:
	match visual:
		"medkit":
			var b := Stage4Props.box(Vector3(0.44, 0.30, 0.32), "cloth_white")
			b.position = Vector3(0, 0.15, 0)
			add_child(b)
			var ch := Stage4Props.box(Vector3(0.24, 0.07, 0.02), "cloth_red")
			ch.position = Vector3(0, 0.15, 0.17)
			add_child(ch)
			var cv := Stage4Props.box(Vector3(0.07, 0.20, 0.02), "cloth_red")
			cv.position = Vector3(0, 0.15, 0.17)
			add_child(cv)
			prompt = "Medicinski paket (+%d)" % int(heal_amount)
		"bandage":
			var roll := Stage4Props.cyl(0.10, 0.16, "cloth_white", -1, 8)
			roll.rotation.x = PI * 0.5
			roll.position = Vector3(0, 0.10, 0)
			add_child(roll)
			prompt = "Zavoji (+%d)" % int(heal_amount)
		_:
			var crate := Stage4Props.box(Vector3(0.60, 0.33, 0.38), "wood_dark")
			crate.position = Vector3(0, 0.17, 0)
			add_child(crate)
			for sx in [-0.16, 0.16]:
				var strap := Stage4Props.box(Vector3(0.05, 0.35, 0.40), "iron_rust")
				strap.position = Vector3(sx, 0.17, 0)
				add_child(strap)
			prompt = "Municija (+%d)" % ammo_amount
	set_box(Vector3(1.05, 0.95, 1.05), Vector3(0, 0.5, 0))


func _do_interact(by: Node3D) -> void:
	if ammo_amount > 0:
		var arsenal := by.find_child("WeaponArsenal", true, false)
		var weapon := by.find_child("WeaponController", true, false)
		var active_slot := int(arsenal.get("active")) if arsenal else 0
		if arsenal and active_slot != 0 and arsenal.has_method("give_weapon"):
			arsenal.give_weapon(active_slot, ammo_amount)
		elif weapon and weapon.has_method("add_reserve_ammo"):
			weapon.add_reserve_ammo(ammo_amount)
		elif weapon:
			for prop in ["reserve_ammo", "ammo_reserve", "reserve"]:
				if prop in weapon:
					weapon.set(prop, int(weapon.get(prop)) + ammo_amount)
					break
	if heal_amount > 0.0 and by.has_method("heal"):
		by.heal(heal_amount)
	notify(prompt, "Preuzeto.")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(queue_free)
