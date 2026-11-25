# Vlado Šipčić: The Last Outlaw — Stage 3 (Oružje, Nišanjenje, Pucanje i Zvuk)

## Implemented in Stage 3
1. **Rifle Equip / Holster & 19-Clip IK Library (`animations/vlado_locomotion.tres`)**:
   - Seamless unslings/holstering of `Rifle_BoltAction` between Vlado's back (`UpperChest` mount) and two-handed ready/aim grips (`RightHand` + `LeftHand`).
   - 10 new combat animations added alongside Stage 2.1 locomotion: `RifleReadyIdle`, `RifleReadyWalk`, `AimIdle`, `AimWalk`, `AimCrouchIdle`, `AimCrouchWalk`, `EquipRifle`, `HolsterRifle`, `FireRecoil`, `ReloadBolt`.
   - Vertical aim pitch tracking rotates `UpperChest` and `WeaponMount` together while aiming and firing.

2. **M48 Bolt-Action Weapon & Ballistics (`weapons/weapon_controller.gd`, `weapons/shooting_target.gd`)**:
   - 5-round internal magazine + 30 reserve ammo (resuppliable at the green/brass **Ammo Crate** near spawn, +15 rounds up to 60).
   - Camera-center raycast ballistics aligned with dynamic screen crosshair & hitmarker (`ui/debug_hud.gd`).
   - 6 interactive shooting range targets across the meadow (`14m` to `50m`), including spring-hinged wood bullseye plates and steel gongs.

3. **Over-the-Shoulder Tactical Camera & Health/Stamina (`player/player_camera.gd`, `player/player_controller.gd`)**:
   - Smooth OTS Aim framing (`2.12m` distance, `+0.62m` right-shoulder offset, `40°` FOV) with spring recoil kick and recovery.
   - Player Health & Stamina bars in HUD; sprinting (`-14/s`) and jumping (`-12`) consume stamina and regenerate smoothly during idle/walk.

4. **Mobile Combat Controls (`ui/mobile_controls.gd`)**:
   - Right-thumb outer/upper combat arc added without overlap:
     - **RIFLE**: Equip / Holster M48 rifle
     - **AIM**: Toggle over-the-shoulder aim sight
     - **FIRE**: Fire bolt-action shot (auto-equips rifle if tapped while holstered)
     - **RLD**: Reload 5-round clip
   - Desktop test keys: `1` or `Q` (Equip/Holster), `V` or Right Mouse (Aim), `F` (Fire), `R` (Reload when rifle equipped / Run when holstered), `WASD` (Move), `Shift` (Sprint), `C` (Crouch), `Space` (Jump).

5. **Procedural Audio & Combat VFX (`audio/sound_manager.gd`, `effects/weapon_effects.gd`)**:
   - Zero external binary bloat: procedural 16-bit 22050 Hz `AudioStreamWAV` synthesis for M48 rifle crack + mountain valley echo, bolt cycle & clip reload, dry fire click, equip rustle, metal gong clang, wood/stone/dirt hits, stride-synced 5-surface footsteps (`dirt`, `grass`, `stone`, `wood`, `water`), and looping mountain wind & river ambience.
   - Auto-cleaning muzzle flash + `OmniLight3D` + smoke puff, glowing tracer streak, surface impact sparks/dust, and spinning brass shell casing ejection.

## Opening on Android (Godot 4.7.2)
1. Extract `Vlado_The_Last_Outlaw_Stage3.zip` to a folder on internal storage (outside `Android/data`).
2. Open **Godot Editor 4.7.2** on Android -> **Import** -> select `project.godot` inside `Vlado_The_Last_Outlaw/`.
3. Godot imports textures & GLB automatically on first load; press **Play** (`montenegro_world.tscn` is the main scene).
