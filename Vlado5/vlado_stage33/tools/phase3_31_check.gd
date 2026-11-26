extends SceneTree
func _initialize(): call_deferred("_run")
func _run():
 var p=load("res://characters/vlado/vlado_character.tscn").instantiate() as PlayerController
 p.set_physics_process(false);var ar=WeaponArsenal.new();ar.name="WeaponArsenal";p.add_child(ar);root.add_child(p)
 for i in 50: await process_frame
 var bad=0
 for slot in range(31):
  ar.show_weapon(slot,true)
  for k in 2:await process_frame
  var held:Dictionary=ar.get("held");var m=held.get(slot) as Node3D
  if slot==0:
   if ar.def_for(slot)==null: bad+=1;print("PHASE3_SLOT_BAD slot=0 reason=no_m48_def")
   else: print("PHASE3_SLOT_OK slot=0 model=M48_back_special back=true")
  elif m==null:
   bad+=1;print("PHASE3_SLOT_BAD slot=",slot," reason=no_model")
  else:
   var markers=0
   for n in m.find_children("Grip*","Marker3D",true,false):markers+=1
   print("PHASE3_SLOT_OK slot=",slot," model=",m.name," markers=",markers)
 print("PHASE3_31_DONE count=31 bad=",bad)
 quit(0 if bad==0 else 1)
