extends SceneTree
const OUT="/tmp/vlado_rebuild/phase4_category/"
func _initialize():call_deferred("_run")
func shot(p:PlayerController,pa:PlayerAnimator,cam:Camera3D,tag:String,action:String,aim:bool=false,speed:float=0.0):
 p.weapon_action=action;p.is_aiming=aim;p.current_horizontal_speed=speed
 for i in 15:await process_frame
 await RenderingServer.frame_post_draw
 var img=root.get_viewport().get_texture().get_image();print("PHASE4_FRAME ",tag," state=",pa.get_active_animation()," err=",img.save_jpg(OUT+tag+".jpg",.92))
func _run():
 DirAccess.make_dir_recursive_absolute(OUT)
 var w=Node3D.new();root.add_child(w);var e=WorldEnvironment.new();var en=Environment.new();en.background_mode=Environment.BG_COLOR;en.background_color=Color(.10,.14,.17);en.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;en.ambient_light_color=Color.WHITE;en.ambient_light_energy=.9;e.environment=en;w.add_child(e)
 var l=DirectionalLight3D.new();l.rotation_degrees=Vector3(-42,-28,0);l.light_energy=1.6;w.add_child(l);var fl=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(8,8);fl.mesh=pm;w.add_child(fl)
 var p=load("res://characters/vlado/vlado_character.tscn").instantiate() as PlayerController;p.set_physics_process(false);var ar=WeaponArsenal.new();ar.name="WeaponArsenal";p.add_child(ar);w.add_child(p)
 var cam=Camera3D.new();w.add_child(cam);cam.transform=Transform3D(Basis.IDENTITY,Vector3(3.8,1.4,.2)).looking_at(Vector3(0,1.15,-.2),Vector3.UP);cam.fov=42
 for i in 50:await process_frame
 p.set_physics_process(false);p.global_position=Vector3.ZERO;p.velocity=Vector3.ZERO;p.is_grounded=true;p.current_locomotion_state="Idle";p.weapon_equipped=true
 for c in p.find_children("*","Camera3D",true,false):(c as Camera3D).current=false
 cam.current=true;var pa=p.get_node("PlayerAnimator") as PlayerAnimator
 ar.show_weapon(3,true);await shot(p,pa,cam,"GasserIdle","");await shot(p,pa,cam,"GasserAim","",true);await shot(p,pa,cam,"GasserFire","Fire",true);await shot(p,pa,cam,"GasserReload","Reload")
 ar.show_weapon(1,true);await shot(p,pa,cam,"RifleIdle","");await shot(p,pa,cam,"RifleAim","",true);await shot(p,pa,cam,"RifleFire","Fire",true);await shot(p,pa,cam,"RifleReload","Reload")
 ar.show_weapon(2,true);await shot(p,pa,cam,"HeavyIdle","");await shot(p,pa,cam,"HeavyFire","Fire",true);await shot(p,pa,cam,"HeavyWalk","",false,1.4)
 print("PHASE4_CATEGORY_DONE");quit()
