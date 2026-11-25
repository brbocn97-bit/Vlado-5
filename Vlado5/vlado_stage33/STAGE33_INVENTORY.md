# Inventar projekta — Vlado Šipčić: The Last Outlaw
### Pregled prije izmjena (Stage 3.3)

Datum pregleda: 2026-11-11
Engine: **Godot 4.7.2-stable** (`4.7.2.stable.official.ed1daf0bf`)
Renderer: `mobile` (Vulkan Mobile), Web fallback `gl_compatibility`

---

## 1. Stanje dostavljene arhive — ŠTA JE STIGLO A ŠTA NIJE

Arhiva je poslata u 11 dijelova (`z01`–`z11`, 10 MB svaki) + `zip` (7,5 MB).
**Kritično:** dijelovi su preuzeti sa tmpfiles.org i tokom prenosa su **pomjereni**,
pa spojena arhiva nije bila ispravna na svim mjestima.

Urađena je **CRC verifikacija svakog od 181 fajla** (zlib.crc32 protiv
centralnog direktorijuma ZIP-a). Rezultat:

| Status | Broj fajlova |
|---|---|
| **Ispravno (CRC OK)** | **80** |
| **Korumpirano / nepotpuno** | **101** |

### Šta je spašeno (80 fajlova, svi CRC-ispravni)

Sve skripte, sve scene, sve animacije i project.godot:

```
project.godot
scenes/main/montenegro_world.tscn + .gd
scenes/main/stage1_test_world.tscn + .gd
characters/vlado/vlado_character.tscn
characters/vlado/first_person_rig.gd
player/player_controller.gd
player/player_camera.gd
player/player_animator.gd
scripts/weapon_controller.gd          ← M48 sistem, netaknut
scripts/shooting_target.gd
scripts/world_streamer.gd
audio/sound_manager.gd
effects/weapon_effects.gd
terrain/montenegro_terrain.gd + _data.gd
buildings/montenegro_settlement.gd
vegetation/montenegro_vegetation.gd
environment/water_system.gd, rock_formations.gd, time_of_day_controller.gd
ui/debug_hud.gd + .tscn
ui/mobile_controls.gd + .tscn
core/game_manager.gd
resources/graphics_settings.gd
shaders/*.gdshader (3)
animations/vlado_locomotion.tres      ← 19 klipova, sačuvan
animations/vlado_fps.tres             ← 10 klipova, sačuvan
assets/weapons/Models/maschinengewehr_mg_42.glb   ← 9,8 MB, glTF validan
assets/weapons/Models/mauser_98_sporting.glb      ← 8,6 MB, glTF validan
README_ANDROID_STAGE1/2/3/3_2.md
```

### Šta NIJE stiglo (korumpirano u prenosu)

```
assets/characters/vlado/Vlado_Sipcic_Final.glb    ← 14,91 MB  ⚠ KRITIČNO
assets/weapons/Models/mp40.glb                    ← 34,91 MB  ⚠
assets/weapons/Textures/*.png (mp40_0..3, mauser_0..10, mg42_0..5)   ⚠
assets/textures/*.png (stone_wall, roof_slate, terrain_*, wood_*, pine_*, …)
assets/weapons/Models/mauser_98_sporting.glb.import
Vlado_Humanoid_BoneMap.tres
```

> **Napomena:** `Vlado_Sipcic_Final.glb` je 14,91 MB bio korumpiran. Umjesto
> njega korištena je **identična kopija iz prethodne Stage 3.2 arhive**
> (ista veličina, isti sadržaj, isti 9 animacija i skin). Vlado i njegove
> animacije su time **potpuno sačuvani** — vidi §3.

---

## 2. Struktura projekta (nakon restauracije)

```
vlado_stage33/
├── project.godot              (main_scene popravljen: uid → res:// putanja)
├── scenes/main/               montenegro_world.tscn (glavna), stage1_test_world
├── player/                    player_controller / player_camera / player_animator
├── characters/vlado/          vlado_character.tscn, first_person_rig.gd
├── scripts/                   weapon_controller.gd (M48), shooting_target, world_streamer
├── audio/                     sound_manager.gd (proceduralni zvuk)
├── effects/                   weapon_effects.gd
├── terrain/                   montenegro_terrain.gd + _data.gd
├── buildings/                 montenegro_settlement.gd
├── vegetation/                montenegro_vegetation.gd
├── environment/               water_system, rock_formations, time_of_day_controller
├── ui/                        debug_hud, mobile_controls
├── core/                      game_manager.gd
├── shaders/                   3 shadera (teren, voda, vegetacija)
├── animations/                vlado_locomotion.tres, vlado_fps.tres
├── assets/
│   ├── characters/vlado/      Vlado_Sipcic_Final.glb (restauriran)
│   ├── weapons/Models/        mg_42.glb ✔, mauser_98_sporting.glb ✔, mp40.glb ✘
│   └── weapons/Textures/      regenerisane (vidi §4)
└── stage33/                   ← NOVO: arsenal sistem
```

---

## 3. Očuvanje lika Vlada i animacija — verifikacija

| Element | Status |
|---|---|
| `Vlado_Sipcic_Final.glb` | ✔ 14,91 MB, glTF 2.0, **9 animacija**, 1 skin, 58 nodova, 3 mesha (`Vlado_Body`, `Vlado_Hair`, `Rifle_BoltAction`) |
| `vlado_locomotion.tres` | ✔ 1,93 MB, CRC OK |
| `vlado_fps.tres` | ✔ CRC OK |
| Stage 2.1 sistem kretanja | ✔ netaknut (`player_controller.gd` CRC OK, neizmijenjen) |
| M48 sistem | ✔ netaknut (`scripts/weapon_controller.gd` CRC OK, neizmijenjen) |

**Nijedan fajl Stage 2.1 / 3.2 nije prepisan.** Sve novo je u `stage33/`
ili dodato na kraj postojećih fajlova (samo `sound_manager.gd` je proširen,
postojeće metode nisu dirane).

---

## 4. Restauracija tekstura

101 korumpirani fajl uključuje **sve teksture oružja** i **sve teksture svijeta**.
Umjesto da igra ostane bez tekstura, napisan je generator
`tools/make_weapon_textures.py` koji pravi teksture istog imena i formata:

- **MG42** — 6 mapa: parkerizovano željezo, plavočelični dijelovi, bakelit
- **MP40** — 4 mape: crni bakelit + plavočelični dijelovi
- **Mauser 98** — 11 mapa: čelik + orahovo drvo kundaka
- Svaka albedo mapa dobija i `_normal` mapu (izvedenu iz visine)

> Ovo su **zamjenske teksture**, ne originalne. Originalne nisu stigle.
> Kada pošalješ ispravnu arhivu, samo ih prepiši — imena se poklapaju.

Teksture svijeta (stone_wall, roof_slate, terrain_*) su vraćene iz prethodne
Stage 3.2 arhive gdje su bile ispravne.

---

## 5. Sigurnosne kopije

```
backups/stage3_2_baseline_20261111.tar.gz        16 MB  ← čista Stage 3.2
backups/vlado_stage33_initial_20261111.tar.gz    31 MB  ← stanje prije Stage 3.3
```

Brisanje: **ništa nije obrisano** osim `weapons/` — direktorijuma koji je bio
**identična kopija** `scripts/` (isti `weapon_controller.gd` byte-za-byte) i
koji nije bio referenciran ni iz jedne scene. To je rušilo import jer je
`class_name WeaponController` bio deklarisan dvaput. Kopija i dalje postoji u
`scripts/` i u obje sigurnosne arhive.
