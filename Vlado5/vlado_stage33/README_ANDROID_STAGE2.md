# Vlado Šipčić: The Last Outlaw — Stage 2 (Android Godot 4.7.2)

## Main Scene
- `res://scenes/main/montenegro_world.tscn` (set as `run/main_scene` in `project.godot`)
- `res://scenes/main/stage1_test_world.tscn` remains preserved for Stage 1 regression testing.

## Controls (Samsung Galaxy S25 Ultra Touch + Desktop Test)
- **MOVE Joystick (bottom-left):** Walk (`1.80 m/s`) by default.
- **RUN / SPRINT / CROUCH / JUMP (bottom-right):** Toggle Run (`4.60 m/s`), Sprint (`6.20 m/s`), Crouch (`1.15 m/s`), or Jump.
- **Right-Side Screen Drag:** Orbit camera smoothly around Vlado.
- **Top-Left HUD Buttons:**
  - `Quality`: Cycle `Low` -> `Balanced` -> `S25 Ultra High` (adjusts render scale, MSAA, shadow distance, vegetation LOD distances).
  - `Time`: Cycle `Morning` -> `Noon` -> `Dusk` -> `Night` -> `Auto` (live sun, sky, mountain fog, and village lanterns/hearth windows).
  - `Cam -` / `Cam +` & `Shldr`: Adjust camera distance and shoulder framing.

## Stage 2 Modules
- `terrain/montenegro_terrain_data.gd` & `terrain/montenegro_terrain.gd`: `600m x 600m` `4x4` chunked terrain with dirt road, mountain footpath, river valley, and `ConcavePolygonShape3D` collision.
- `shaders/`: `montenegro_terrain.gdshader`, `mountain_water.gdshader`, `vegetation_foliage.gdshader`.
- `environment/`: `water_system.gd`, `rock_formations.gd`, `time_of_day_controller.gd`.
- `vegetation/montenegro_vegetation.gd`: Chunked LOD `Crni Bor` pines, Balkan beech trees, shrubs, wild grass tufts, and fallen logs.
- `buildings/montenegro_settlement.gd`: Montenegrin stone houses (`Kuće`), stone-and-timber barn, stone village well (`Bunar`), dry-stone walls (`Međe`), river bridge, and night lanterns.
