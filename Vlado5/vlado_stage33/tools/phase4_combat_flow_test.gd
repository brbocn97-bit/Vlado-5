extends SceneTree
func _initialize():call_deferred("_run")
func wf(n:int):
 for i in n:await process_frame
func _run():
 var p=load("res://characters/vlado/vlado_character.tscn").instantiate() as PlayerController;p.set_physics_process(false);var ar=WeaponArsenal.new();ar.name="WeaponArsenal";p.add_child(ar);root.add_child(p);await wf(50);p.set_physics_process(false);p.is_grounded=true;p.velocity=Vector3.ZERO;p.current_locomotion_state="Idle";p.current_horizontal_speed=0;p.weapon_equipped=true
 ar.unlock_full_arsenal();ar.show_weapon(3,true);await wf(10);var pa=p.get_node("PlayerAnimator") as PlayerAnimator;var bad=0;var before=ar.ammo_for(3).duplicate();var fired=ar.try_fire();await wf(3);var during=pa.get_active_animation();await create_timer(.22).timeout;var after=ar.ammo_for(3).duplicate();var fire_ok=fired and int(after[0])==int(before[0])-1 and during=="PistolFire" and p.weapon_action=="";bad+=0 if fire_ok else 1;print("PHASE4_COMBAT gasser_fire before=",before," after=",after," state=",during," ok=",fire_ok)
 var started=ar.reload();await wf(3);var rs=pa.get_active_animation();await create_timer(1.9).timeout;var loaded=ar.ammo_for(3).duplicate();var reload_ok=started and rs=="PistolReload" and int(loaded[0])==6 and p.weapon_action=="";bad+=0 if reload_ok else 1;print("PHASE4_COMBAT gasser_reload ammo=",loaded," state=",rs," ok=",reload_ok)
 await ar.switch_to(2);var hb=ar.ammo_for(2).duplicate();var hf=ar.try_fire();await wf(3);var hs=pa.get_active_animation();await create_timer(.20).timeout;var ha=ar.ammo_for(2).duplicate();var heavy_ok=hf and int(ha[0])==int(hb[0])-1 and hs=="HeavyFire";bad+=0 if heavy_ok else 1;print("PHASE4_COMBAT heavy_fire before=",hb," after=",ha," state=",hs," ok=",heavy_ok)
 print("PHASE4_COMBAT_DONE bad=",bad);quit(0 if bad==0 else 1)
