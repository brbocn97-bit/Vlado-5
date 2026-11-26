extends SceneTree
func _initialize():call_deferred("_run")
func wait_frames(n:int):
 for i in n:await process_frame
func check(tag:String,p:PlayerController,pa:PlayerAnimator,ar:WeaponArsenal,expect:String)->int:
 var got=pa.get_active_animation();var ok=got==expect;print("PHASE4_SWITCH ",tag," action=",p.weapon_action," state=",got," active=",ar.active," ok=",ok);return 0 if ok else 1
func _run():
 var p=load("res://characters/vlado/vlado_character.tscn").instantiate() as PlayerController;p.set_physics_process(false);var ar=WeaponArsenal.new();ar.name="WeaponArsenal";p.add_child(ar);root.add_child(p);await wait_frames(50)
 p.set_physics_process(false);p.weapon_equipped=true;p.is_grounded=true;p.velocity=Vector3.ZERO;p.current_horizontal_speed=0;p.current_locomotion_state="Idle";ar.unlock_full_arsenal();ar.show_weapon(3,true);await wait_frames(8);var pa=p.get_node("PlayerAnimator") as PlayerAnimator;var bad=0
 ar.switch_to(1);await create_timer(.07).timeout;bad+=check("GasserHolster",p,pa,ar,"PistolHolster");await create_timer(.18).timeout;bad+=check("RifleEquip",p,pa,ar,"RifleEquip");await create_timer(.38).timeout;bad+=check("RifleReady",p,pa,ar,"RifleIdle")
 ar.switch_to(2);await create_timer(.07).timeout;bad+=check("RifleHolster",p,pa,ar,"RifleHolster");await create_timer(.18).timeout;bad+=check("HeavyEquip",p,pa,ar,"RifleEquip");await create_timer(.38).timeout;bad+=check("HeavyReady",p,pa,ar,"HeavyIdle")
 print("PHASE4_SWITCH_DONE bad=",bad);quit(0 if bad==0 else 1)
