extends SceneTree
var fire_count:=0
var joy_events:=0
func _initialize():call_deferred("_run")
func circle_rect(c:Vector2,r:float,rect:Rect2)->bool:
 var q=Vector2(clampf(c.x,rect.position.x,rect.end.x),clampf(c.y,rect.position.y,rect.end.y));return c.distance_to(q)<r+4.0
func _run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("size="):
   var q=arg.trim_prefix("size=").split("x");root.size=Vector2i(int(q[0]),int(q[1]))
 var mc=load("res://ui/mobile_controls.tscn").instantiate() as MobileControls;root.add_child(mc)
 var ih=load("res://ui/immersive_hud.gd").new();root.add_child(ih)
 var dh=load("res://ui/debug_hud.tscn").instantiate() as DebugHUD;root.add_child(dh)
 for i in 8:await process_frame
 mc.fire_pressed.connect(func():fire_count+=1);mc.joystick_moved.connect(func(_v):joy_events+=1)
 var sz=root.get_viewport().get_visible_rect().size;var b:Dictionary=mc.get("_buttons");var bad=0;var ids=b.keys()
 for id in b:
  var p:Vector2=b[id]["pos"];var r:float=b[id]["r"]
  if p.x-r<0 or p.y-r<0 or p.x+r>sz.x or p.y+r>sz.y:bad+=1;print("PHASE7_BAD bounds ",id)
 for i in range(ids.size()):
  for j in range(i+1,ids.size()):
   var a=b[ids[i]];var c=b[ids[j]]
   if (a["pos"] as Vector2).distance_to(c["pos"])<float(a["r"])+float(c["r"])+6.0:bad+=1;print("PHASE7_BAD overlap ",ids[i],"/",ids[j])
 var panels:Array[Control]=[ih.get("_top"),ih.get("_mission"),ih.get("_bottom"),dh.get_node("Panel")]
 for id in b:
  for panel in panels:
   if panel and circle_rect(b[id]["pos"],b[id]["r"],panel.get_global_rect()):bad+=1;print("PHASE7_BAD panel ",id,"/",panel.name)
 var fire=InputEventScreenTouch.new();fire.index=7;fire.pressed=true;fire.position=mc.get_button_center("fire");mc._input(fire);var release=InputEventScreenTouch.new();release.index=7;release.pressed=false;release.position=fire.position;mc._input(release)
 if fire_count!=1 or mc.is_fire_held():bad+=1;print("PHASE7_BAD fire")
 var jt=InputEventScreenTouch.new();jt.index=3;jt.pressed=true;jt.position=Vector2(sz.x*.12,sz.y*.78);mc._input(jt);var jd=InputEventScreenDrag.new();jd.index=3;jd.position=jt.position+Vector2(55,-25);jd.relative=Vector2(55,-25);mc._input(jd)
 if mc.get_move_vector().length()<=.12:bad+=1;print("PHASE7_BAD joystick")
 jt.pressed=false;mc._input(jt)
 if mc.get_move_vector()!=Vector2.ZERO or joy_events<2:bad+=1;print("PHASE7_BAD joystick reset")
 if dh.get_node("Panel/Margin/VBox/TelemetryLabel").visible or dh.get_node("Panel/Margin/VBox/ControlsRow").visible:bad+=1;print("PHASE7_BAD debug UI visible")
 print("PHASE7_PHONE_UI size=",sz," buttons=",b.size()," fire=",fire_count," joy=",joy_events," bad=",bad);quit(0 if bad==0 else 1)
