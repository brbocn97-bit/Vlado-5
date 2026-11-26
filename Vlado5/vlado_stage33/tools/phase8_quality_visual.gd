extends SceneTree
const OUT="/tmp/vlado_quality/quality_visual/"
func _initialize():call_deferred("_run")
func _run():
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(2340,1080)
 var bg=ColorRect.new();bg.color=Color(.055,.075,.065);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(bg)
 var title=Label.new();title.text="DURMITOR  •  ANDROID PHONE PREVIEW";title.position=Vector2(50,44);title.add_theme_font_size_override("font_size",28);root.add_child(title)
 var hud=load("res://ui/immersive_hud.gd").new();root.add_child(hud);for i in 5:await process_frame;hud._toggle_settings();var qm=root.get_node("QualityManager")
 for entry in [[0,"LOW"],[1,"MEDIUM"],[2,"HIGH"]]:
  hud._select_quality(entry[0]);for i in 4:await process_frame;await RenderingServer.frame_post_draw;var img=root.get_viewport().get_texture().get_image();print("PHASE8_VISUAL ",entry[1]," err=",img.save_jpg(OUT+entry[1]+".jpg",.92))
 print("PHASE8_VISUAL_DONE");quit()
