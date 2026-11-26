# Build and test

## Tools

- Godot: 4.7.2
- Blender: 4.3.2 for the delivered `.blend`
- Android phone testing and ADB: not available in this Codespace
- APK builds: only at stable checkpoints

## Headless checks

```bash
godot --headless --editor --path Vlado5/vlado_stage33 --import --quit
godot --headless --editor --path Vlado5/vlado_stage33 --quit
godot --headless --path Vlado5/vlado_stage33 --script res://tools/original_vlado_runtime_audit.gd
```

## Blender check

```bash
/workspaces/tools/blender-4.3.2-linux-x64/blender --background \
  Vlado5/vlado_stage33/blender/Vlado_Sipcic.blend \
  --python-expr 'import bpy; arm=bpy.data.armatures[0]; print(len(arm.bones), len(bpy.data.actions))'
```
