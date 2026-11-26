extends SceneTree
func _initialize():call_deferred("_run")
func approx(a:float,b:float)->bool:return absf(a-b)<.001
func _run():
 root.size=Vector2i(2340,1080)
 var qm=root.get_node_or_null("QualityManager");var bad=0
 if qm==null:print("PHASE8_BAD no QualityManager");quit(1);return
 var expected=[[0,30,.65,false,80.0],[1,45,.80,true,160.0],[2,60,1.0,true,280.0]]
 for e in expected:
  qm.set_tier(e[0],true);await process_frame
  var ok=int(qm.tier)==e[0] and qm.target_fps==e[1] and approx(qm.screen_scale,e[2]) and qm.shadow_enabled==e[3] and approx(qm.foliage_range,e[4]) and Engine.max_fps==e[1] and approx(root.get_viewport().scaling_3d_scale,e[2])
  if not ok:bad+=1;print("PHASE8_BAD profile ",e[0])
  print("PHASE8_PROFILE tier=",qm.tier_name," fps=",qm.target_fps," scale=",qm.screen_scale," foliage=",qm.foliage_range," shadows=",qm.shadow_enabled," ok=",ok)
 var cfg:=ConfigFile.new();var loaded=cfg.load("user://graphics_quality.cfg")==OK;var saved=int(cfg.get_value("graphics","tier",-1));if not loaded or saved!=2:bad+=1;print("PHASE8_BAD persistence loaded=",loaded," saved=",saved)
 var hud=load("res://ui/immersive_hud.gd").new();root.add_child(hud);for i in 5:await process_frame
 hud._toggle_settings();var panel=hud.get("_settings") as PanelContainer;var buttons:Array=hud.get("_quality_buttons");var label=hud.get("_quality_label") as Label
 if panel==null or not panel.visible or buttons.size()!=3 or label==null or label.text.find("HIGH")<0:bad+=1;print("PHASE8_BAD settings UI")
 hud._select_quality(0);await process_frame
 if int(qm.tier)!=0 or label.text.find("LOW")<0 or not buttons[0].disabled:bad+=1;print("PHASE8_BAD UI select LOW")
 hud._select_quality(1);await process_frame
 if int(qm.tier)!=1 or label.text.find("MEDIUM")<0 or not buttons[1].disabled:bad+=1;print("PHASE8_BAD UI select MEDIUM")
 print("PHASE8_QUALITY_DONE profiles=3 saved=",saved," ui_buttons=",buttons.size()," bad=",bad);quit(0 if bad==0 else 1)
