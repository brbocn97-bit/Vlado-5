# Vlado Šipčić: The Last Outlaw — Stage 3.2 (Dual Aim System: Third-Person OTS + True First-Person FPS)

## Implemented in Stage 3.2
1. **Two Independent Switchable Aiming Modes (`player/player_controller.gd`, `player/player_camera.gd`)**:
   - **Mode A — Third-Person Over-The-Shoulder (`THIRD PERSON`)**:
     - Retains full 3rd-person character visibility with refined right-shoulder OTS camera (`2.12m` distance, `+0.62m` shoulder offset, `40°` FOV, collision avoidance via `SpringArm3D`).
     - Smooth upper-body pitch lock (`UpperChest` + `WeaponMount`) and two-handed M48 palm-contact grips (`RightHand` on stock neck/trigger, `LeftHand` cradling wooden fore-end).
   - **Mode B — True First-Person (`FIRST PERSON`)**:
     - Dedicated First-Person camera at Vlado's standing (`1.69 m`) and crouching (`1.18 m`) eye height with expanded vertical pitch bounds (`-72°` to `+76°`), `62°` ready / `46°` ADS world FOV, and zero standing camera shake.
     - 3rd-person `VisualRoot` switches smoothly to `SHADOW_CASTING_SETTING_SHADOWS_ONLY` in FPS mode so Vlado continues casting real-time body and rifle shadows across the Montenegro terrain without head/chest clipping.
   - Smooth transitions (`_fp_blend`), independent TPS/FPS H/V touch and mouse sensitivities, continuous yaw preservation (zero mode-switch rotation jump), and automatic pitch clamping back to TPS limits when returning to Third-Person.

2. **True First-Person Foreground Rig from Original Assets (`characters/vlado/first_person_rig.gd`)**:
   - Constructed directly from `assets/characters/vlado/Vlado_Sipcic_Final.glb` (3,058 extracted `Vlado_Body` arm/hand/finger triangles + actual `Rifle_BoltAction` mesh; zero generic asset substitutions).
   - Rendered via `CanvasLayer -> SubViewportContainer -> SubViewport` (`transparent_bg = true`, `own_world_3d = true`, independent `52° -> 44°` weapon FOV) with sun/sky-bounce lighting synced live to Montenegro `SunLight` / `TimeOfDayController`, plus close-up FPS muzzle flash & warm `OmniLight3D`.

3. **Dedicated 10-Clip FPS Animation Library (`animations/vlado_fps.tres`) & Upgraded TPS Grips (`animations/vlado_locomotion.tres`)**:
   - 10 dedicated FPS clips driven by `FPSAnimationTree` (`AnimationNodeStateMachine` + `TimeScale`):
     `FPS_WeaponIdle`, `FPS_AimIdle`, `FPS_Walk`, `FPS_Run`, `FPS_Sprint`, `FPS_Fire`, `FPS_Recoil`, `FPS_ReloadBolt`, `FPS_Equip`, `FPS_Holster`.
   - Upgraded all 10 TPS combat clips in `vlado_locomotion.tres` with exact palm-contact hand/finger wrap while preserving all 9 Stage 2.1 locomotion clips (`BROKEN_TRACKS = 0`).

4. **Consistent Ballistics, Mobile Controls & HUD (`weapons/weapon_controller.gd`, `ui/mobile_controls.gd`, `ui/debug_hud.gd`)**:
   - Single camera-center raycast across TPS OTS and FPS ADS: iron sights, fine ADS crosshair dot, hitmarker, bullet tracer, and target impact point agree consistently.
   - Prevents firing during `FPS_Sprint` carry; tapping `AIM` smoothly exits sprint into ADS.
   - Added non-overlapping `VIEW` toggle button (`FPS` / `TPS` indicator) to `MobileControls` alongside `RIFLE`, `AIM`, `FIRE`, `RLD`, `JUMP`, `CROUCH`, `RUN`, `SPRINT` (`>= 120 px` center spacing on 1920x1080), plus desktop keybind `E` / `Tab`.
   - Added live `THIRD PERSON` / `FIRST PERSON` status badge to `DebugHUD`.

## Controls (Touch & Desktop Test)
- **Touch (Galaxy S25 Ultra / Android)**:
  - Left thumb: Dynamic floating `MOVE` stick
  - Right screen drag: Camera look (TPS & FPS independent H/V sensitivity)
  - Right buttons: `VIEW` (TPS/FPS), `RIFLE` (Equip/Holster), `AIM` (OTS/Iron-Sight ADS), `FIRE`, `RLD`, `JUMP`, `CROUCH`, `RUN`, `SPRINT`
- **Keyboard / Mouse Test**: `WASD` Move, `E` or `Tab` View Mode (TPS/FPS), `1`/`Q` Equip/Holster, `V` Aim, `F` Fire, `R` Reload/Run, `Shift` Sprint, `C` Crouch, `Space` Jump, Mouse Drag Look.

## Opening on Android (Godot 4.7.2)
1. Extract `Vlado_The_Last_Outlaw_Stage3_2.zip` to internal storage (outside `Android/data`).
2. Import `Vlado_The_Last_Outlaw/project.godot` in **Godot Editor 4.7.2** and press **Play** (`montenegro_world.tscn`).
3. Stage 3 rollback archive remains untouched at `Vlado_The_Last_Outlaw_Stage3.zip`.
