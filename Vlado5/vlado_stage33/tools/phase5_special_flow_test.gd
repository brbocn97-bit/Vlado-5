extends SceneTree
func _initialize():call_deferred("_run")
func wf(n:int):
 for i in n:await process_frame
func _run():
 var p=load("res://characters/vlado/vlado_character.tscn").instantiate() as PlayerController;p.set_physics_process(false);var ar=WeaponArsenal.new();ar.name="WeaponArsenal";p.add_child(ar);root.add_child(p);await wf(50);p.set_physics_process(false);p.global_position=Vector3.ZERO;p.is_grounded=true;p.velocity=Vector3.ZERO;p.current_locomotion_state="Idle";p.current_horizontal_speed=0;p.weapon_equipped=true;ar.unlock_full_arsenal();var pa=p.get_node("PlayerAnimator") as PlayerAnimator;var bad=0
 ar.show_weapon(29,true);await wf(8);var gb=ar.ammo_for(29).duplicate();var gf=ar.try_fire();await create_timer(.08).timeout;var gs=pa.get_active_animation();var pre=(ar.get("_grenades") as Array).size();await create_timer(.16).timeout;var released=(ar.get("_grenades") as Array).size();var throw_ok=gf and gs=="GrenadeThrow" and pre==0 and released==1 and int(ar.ammo_for(29)[0])==0;bad+=0 if throw_ok else 1;print("PHASE5_FLOW grenade_throw before=",gb," pre=",pre," released=",released," state=",gs," ok=",throw_ok)
 await create_timer(1.25).timeout;var ga=ar.ammo_for(29).duplicate();var reload_ok=int(ga[0])==1 and int(ga[1])==3 and not ar.is_reloading();bad+=0 if reload_ok else 1;print("PHASE5_FLOW grenade_reload after=",ga," ok=",reload_ok)
 ar.show_weapon(30,true);await wf(8);var mb=ar.ammo_for(30).duplicate();var mf=ar.try_fire();await create_timer(.08).timeout;var ms=pa.get_active_animation();await create_timer(.18).timeout;var ma=ar.ammo_for(30).duplicate();var melee_ok=mf and ms=="MeleeAttack" and ma==mb and p.weapon_action=="";bad+=0 if melee_ok else 1;print("PHASE5_FLOW melee_attack ammo=",ma," state=",ms," ok=",melee_ok)
 print("PHASE5_FLOW_DONE bad=",bad);quit(0 if bad==0 else 1)
