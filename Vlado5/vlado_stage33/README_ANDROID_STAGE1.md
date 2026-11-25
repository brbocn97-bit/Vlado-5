# Vlado Šipčić: The Last Outlaw — Stage 1 (Project Foundation)

## Opening on Samsung Galaxy S25 Ultra (Godot 4.7.2 Android Editor)
1. Download `Vlado_The_Last_Outlaw_Stage1.zip` and extract it to a folder on your phone (e.g. `Documents/Godot/Vlado_The_Last_Outlaw/`).
2. Open **Godot 4.7.2** on Android -> **Import** -> select `project.godot` inside the extracted folder.
3. On first open, Godot generates the `.godot/` import cache for your phone automatically (`Forward Mobile`, `ETC2/ASTC`, `Basis Universal`).
4. Press **Play** to launch `res://scenes/main/stage1_test_world.tscn`.

## Stage 1 Mobile Touchscreen Controls (Samsung Galaxy S25 Ultra)
- **Bottom-Left (`MOVE` Virtual Joystick):** Default movement is **Walking (`1.8 m/s`)** with a natural human stride. Deflect gently for slower walk, full outer ring for steady walk.
- **Right Side Open Area (above/left of action buttons):** Drag anywhere on the open right screen area for **360° camera orbit & vertical pitch** — works simultaneously while holding the left joystick!
- **Bottom-Right Tactical Button Arc:**
  - **`RUN` (upper-left circle):** Tap to toggle **Running (`4.6 m/s`)** ON/OFF.
  - **`SPRINT` (top-right circle):** Tap to toggle **Sprinting (`6.2 m/s`)** ON/OFF.
  - **`CROUCH` (bottom-left of cluster):** Tap to toggle **Crouching** ON/OFF (stationary crouch stance + crouched walk at `1.15 m/s` when moving; checks overhead clearance before standing).
  - **`JUMP` (large bottom-right circle):** Tap to **Jump** cleanly with landing recovery.
- **Top-Left Debug HUD Bar:**
  - `Quality`: cycle `S25 Ultra High` / `Balanced` / `Low`
  - `Cam -` / `Cam +`: adjust `SpringArm3D` distance (`2.0 m` – `5.5 m`, default `3.15 m`)
  - `Shldr: R / C / L`: cycle over-shoulder camera offset (`+0.32 m`, `0.0 m`, `-0.32 m`)
EOF
