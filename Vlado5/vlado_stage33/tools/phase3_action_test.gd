extends SceneTree
const OUT="/tmp/vlado_rebuild/phase3_proofs/"
func _initialize():call_deferred("_run")
func _run():
 DirAccess.make_dir_recursive_absolute(OUT)
 var w=Node3D.new();root.add_child(w);var e=WorldEnvironment.new();var en=Environment.new();en.background_mode=Environment.BG_COLOR;en.background_color=Color(.12,.16,.19);en.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;en.ambient_light_color=Color.WHITE;en.ambient_light_energy=.85;e.environment=en;w.add_child(e)
 var l=DirectionalLight3D.new();l.rotation_degrees=Vector3(-42,-28,0);l.light_energy=1.5;w.add_child(l)
 var fl=MeshInstance3D.new();var pm=PlaneMesh.new();pm.size=Vector2(8,8);fl.mesh=pm;w.add_child(fl)
 var p=load("res://characters/vlado/vlado_character.tscn").instantiate() as PlayerController;p.set_physics_process(false);var ar=WeaponArsenal.new();ar.name="WeaponArsenal";p.add_child(ar);w.add_child(p)
 var cam=Camera3D.new();w.add_child(cam);cam.transform=Transform3D(Basis.IDENTITY,Vector3(3.8,1.4,.2)).looking_at(Vector3(0,1.15,-.2),Vector3.UP);cam.fov=42
 for i in 50:await process_frame
 p.set_physics_process(false);p.global_position=Vector3.ZERO;p.velocity=Vector3.ZERO;p.is_grounded=true;p.current_locomotion_state="Idle";p.current_horizontal_speed=0
 for c in p.find_children("*","Camera3D",true,false):(c as Camera3D).current=false
 cam.current=true;ar.show_weapon(5,true);p.weapon_equipped=true
 var pa=p.get_node("PlayerAnimator") as PlayerAnimator
 for item in [["Equip",.22],["Fire",.07],["Reload",.55],["",.1]]:
  p.weapon_action=item[0]
  for i in 10:await process_frame
  var ap=p.find_child("AnimationPlayer",true,false) as AnimationPlayer
  if ap and ap.current_animation_length>0:ap.seek(minf(float(item[1]),ap.current_animation_length),true)
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  var n="Idle" if item[0]=="" else item[0];var img=root.get_viewport().get_texture().get_image();print("PHASE3_FRAME ",n," state=",pa.get_active_animation()," err=",img.save_jpg(OUT+n+".jpg",.91))
 print("PHASE3_DONE");quit()
