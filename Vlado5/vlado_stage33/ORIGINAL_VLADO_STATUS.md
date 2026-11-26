# Original Vlado integration status

## Runtime audit

- Main scene: `res://scenes/main/montenegro_world.tscn`
- Active model: `res://assets/characters/vlado/vlado_sipcic.glb`
- Meshes: `Vlado_Body`, `Vlado_Hair`, `Rifle_Prop`
- Skeleton bones: 44
- Original animations: `idle`, `idle_rifle`, `jump`, `jump_in_place`, `jump_rifle`, `jump_rifle_in_place`, `run`, `run_rifle`
- Blender source: `blender/Vlado_Sipcic.blend`
- Blender audit: 1 armature, 44 bones, 8 Actions

The original GLB and `.blend` were copied byte-for-byte from `Vlado_Sipcic_Godot.zip`. The old re-rigged and final character assets are removed from this rebuild branch.

## Animation mapping

| GAME STATE | ORIGINAL CLIP | STATUS | CUSTOM ANIMATION REQUIRED |
|---|---|---|---|
| Idle | idle | available | no |
| Walking | run | available, lower AnimationTree speed | no |
| Running | run | available | no |
| Sprinting | run | available, higher AnimationTree speed | no |
| JumpStart / Jumping / Landing | jump_in_place | available | no |
| RifleIdle / RifleAim | idle_rifle | available | no |
| RifleWalk / RifleRun / HeavyWalk | run_rifle | available | no |
| ArmedJump | jump_rifle_in_place | available | no |
| Crouch idle/walk | idle/run | neutral fallback; custom missing | yes |
| Pistol idle/aim/fire/reload | idle | neutral fallback; custom missing | yes |
| Rifle fire/reload | idle_rifle/run_rifle | neutral fallback; custom missing | yes |
| Grenade throw | idle | neutral fallback; custom missing | yes |
| Melee attack | idle | neutral fallback; custom missing | yes |
| Hit reactions | idle | neutral fallback; custom missing | yes |
| Death | idle | neutral fallback; custom missing | yes |
| Interaction/pickup | idle | neutral fallback; custom missing | yes |
| Roll/turn | idle/run | neutral fallback; custom missing | yes |

No bind-pose or bone-retarget operation was applied to the original 44-bone rig.
