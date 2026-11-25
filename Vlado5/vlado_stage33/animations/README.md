# Animations — Stage 2.1 Locomotion Overhaul

`res://animations/vlado_locomotion.tres` is an external Godot `AnimationLibrary` (`vlado_loco`) built specifically for `Vlado_Sipcic_Final.glb`'s 54-bone rig without altering the master GLB file.

## Clips (`vlado_loco` library)
| Clip | Duration | Loop | Reference Speed | Notes |
| --- | --- | --- | --- | --- |
| `Idle` | `3.20 s` | Yes | `0.00 m/s` | Breathing, natural weight sway, grounded heels & toes |
| `Walking` | `0.88 s` | Yes | `1.65 m/s` | Upright compass gait, heel-to-toe roll, 0% flight, counter-rotated arms |
| `Running` | `0.74 s` | Yes | `4.35 m/s` | ~11° forward lean, tucked elbows, crisp swing & flight phases |
| `Sprinting` | `0.56 s` | Yes | `6.40 m/s` | ~23° attack lean, closed fists, explosive stride drive & recovery |
| `CrouchIdle` | `2.40 s` | Yes | `0.00 m/s` | Compact ~0.70 m hip height, balanced stance |
| `CrouchWalk` | `0.96 s` | Yes | `1.35 m/s` | Low-profile stealth step with grounded boots |
| `JumpStart` | `0.24 s` | No | — | Anticipation dip -> upward launch drive |
| `JumpAir` | `0.96 s` | Yes | — | Tucked lead knee, bent trailing heel, mid-air arm balance |
| `Landing` | `0.38 s` | No | — | Knee impact absorption smoothly recovering to standing/moving |

`PlayerAnimator` loads this library at runtime into `AnimationPlayer`, runs an `AnimationNodeStateMachine` + `TimeScale` graph on `LocomotionTree`, and applies subtle post-evaluation `Skeleton3D.skeleton_updated` turn banking, slope lean, and `UpperChest -> WeaponMount` sync.
