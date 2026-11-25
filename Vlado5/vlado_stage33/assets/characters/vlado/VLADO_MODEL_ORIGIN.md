# Vlado model origin

The game uses `Vlado_Sipcic_Final.glb` as the character master asset.

- The existing project asset is a 2.7 MB glTF binary with the `Vlado_Sipcic_Final` rig,
  body, hair and `Rifle_BoltAction` meshes.
- The Humanoid skeleton mapping is stored in `Vlado_Humanoid_BoneMap.tres`.
- Locomotion and combat animation libraries target this same rig:
  `res://animations/vlado_locomotion.tres`
  `res://animations/vlado_fps.tres`.
- The model must not be replaced by a generic soldier or regenerated as a new skeleton.
- The original Drive link is listed as the requested source:
  `https://drive.google.com/file/d/1uSdJKowq6juj1aZhdyV3JHzDourJ9jsr/view`.
