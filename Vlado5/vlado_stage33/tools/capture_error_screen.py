from PIL import Image, ImageDraw

OUTPUT = "/workspaces/Vlado-5/Vlado5/vlado_stage33/build/captures/godot_error_1280x720.png"

image = Image.new("RGB", (1280, 720), (24, 28, 33))
draw = ImageDraw.Draw(image)
draw.text((64, 64), "VLADO 5 — LAUNCH OUTPUT", fill=(255, 255, 255))
draw.text((64, 118), "The Godot process initialized Quality and Missions, but ALSA audio was unavailable.", fill=(220, 220, 220))
draw.text((64, 150), "The engine exited in the virtual display before a gameplay screenshot could be captured.", fill=(220, 220, 220))
draw.text((64, 205), "Scene: res://scenes/main/montenegro_world.tscn", fill=(120, 190, 255))
draw.text((64, 237), "Resolution: 1280x720", fill=(120, 190, 255))
draw.text((64, 292), "No gameplay model or 3D scene is represented in this fallback.", fill=(255, 180, 80))
image.save(OUTPUT)
print(OUTPUT)
