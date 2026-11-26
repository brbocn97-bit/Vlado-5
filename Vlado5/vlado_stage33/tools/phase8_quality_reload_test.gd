extends SceneTree
func _initialize():call_deferred("_run")
func _run():
 var qm=root.get_node("QualityManager");await process_frame;var ok=int(qm.tier)==1 and qm.tier_name=="MEDIUM" and qm.target_fps==45 and absf(qm.screen_scale-.8)<.001;print("PHASE8_RELOAD tier=",qm.tier_name," fps=",qm.target_fps," scale=",qm.screen_scale," ok=",ok);quit(0 if ok else 1)
