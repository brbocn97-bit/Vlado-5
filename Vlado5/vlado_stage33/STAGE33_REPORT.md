# STAGE 3.3 + STAGE 4 — Izvještaj o izvršenju
### Vlado Šipčić: The Last Outlaw
Datum: 2026-11-11 · Godot **4.7.2-stable** · Vulkan Mobile

---

## 1. ŠTA JE URAĐENO — ukratko

| # | Zadatak | Status |
|---|---|---|
| 1 | Pregled arhive + CRC verifikacija svih 181 fajla | ✔ urađeno |
| 2 | Sigurnosne kopije prije izmjena | ✔ 2 arhive |
| 3 | Restauracija oštećenih resursa | ✔ (uz ograničenja — vidi §2) |
| 4 | Weapon Arsenal sistem (3 oružja) | ✔ implementirano |
| 5 | M48 netaknut | ✔ verificirano |
| 6 | Vlado + animacije netaknuti | ✔ verificirano |
| 7 | Stage 4 otvoreni svijet 1400×1400 | ✔ 6 regija, radi |
| 8 | Streaming, terase, vegetacija | ✔ radi |
| 9 | Test na 4.7.2 (import + boot) | ✔ čisto |
| 10 | Vizuelna verifikacija | ✔ 7 screenshotova |

---

## 2. ⚠ ŠTA NIJE MOGLO BITI URAĐENO — otvoreno

### 2.1 MP40 model nedostaje

`assets/weapons/Models/mp40.glb` (34,91 MB) je stigao **korumpiran**.
CRC provjera je pala, a glTF parser ne nalazi `glTF` magic ni u jednom
dijelu preuzetog toka.

**Posljedica:** MP40 je u arsenal sistemu **potpuno definisan** (municija
32+96, brzina paljbe 0,092 s, spread, trzaj, zvuk `play_smg_shot()`), ali
**nema 3D model** — u ruci se ne vidi.

Arsenal to podnosi bez rušenja: `_resolve_model_path()` vrati `""`,
`_load_model_for()` vrati `null`, oružje se preskoči i M48 ostaje u ruci.

**Rješenje:** pošalji samo `mp40.glb` ponovo (može i kao jedan fajl,
bez arhive). Sistem će ga odmah preuzeti — putanja je već pravilna.

### 2.2 Teksture oružja su zamjenske

Svih 21 originalnih tekstura oružja je bilo korumpirano. Generisane su
zamjenske istog imena (`tools/make_weapon_textures.py`), sa realnim
materijalima: parkerizovano željezo, plavi čelik, crni bakelit, orahovo drvo.
Kada pošalješ originalne, samo ih prepiši — imena se poklapaju.

### 2.3 Mauser 98 nije ubačen u arsenal

Model je ispravan (27.630 trouglova, 18 površina), ali je to **Gewehr 98 sa
optikom** — snajper, ne standardna puška. U projektu već postoji M48 kao
osnovna puška, pa bi Mauser bio treća puška istog tipa.

Model je uvezen i validiran, ali **nije dodat kao četvrto oružje**.
Reci ako ga želiš kao lovački/snajperski dodatak — dodavanje je ~15 linija.

### 2.4 FPS režim — model se ne prikazuje

Prvo lice radi (animacije `vlado_fps.tres` se koriste), ali teksturisani
model oružja u FPS rig-u se vidi samo za M48 (koji je dio Vlado GLB-a).
MP40/MG42 modeli se montiraju na **TPS skelet** i u prvom licu nijesu vidljivi.
Za pravi FPS prikaz treba `BoneAttachment3D` i na FPS skeletu —
to je sljedeći korak.

### 2.5 Stage 4 nije igriv do kraja

Radi: teren, 6 regija, terase, rijeka, vegetacija, streaming, zgrade,
stražarnica, katun, interakcije, bilješke, NPC dijalog, teleport F5–F10.

Ne radi / nije urađeno:
- **neprijatelji** (`stage4/actors/`) — protivnici su postavljeni kao patrolne snage 1945+; nema njemačkih vojnika
- **zadaci** — ledger broji bilješke, ali nema mission flow
- **vodopadi** — kanjon ima rijeku, ali ne i vodopad
- **ulaz u zgrade u FPS-u** — vrata rade, ali kamera u interijeru nije podešena
- **LOD nivoi** — vegetacija koristi `visibility_range`, nema pravih LOD mesh-eva
- **occluderi** — `BoxOccluder3D` postoji u zgradama, ali occlusion culling je
  isključen u Web buildu (`Occlusion culling is disabled at build-time`)

---

## 3. ŠTA JE VERIFICIRANO — dokazi

### 3.1 Engine testovi (Godot 4.7.2)

```
$ godot --headless --editor --quit --path .
  → 0 ERROR, 0 SCRIPT ERROR

$ godot --headless --path . --quit-after 400
  → [Stage33] arsenal online — 3 weapons defined, 1 owned
  → [Stage4] outer forest: 937 trees in 64 buckets
  → [Stage4] world mounted: 6 regions, 7 clues catalogued
  → 0 ERROR
```

### 3.2 Web build + screenshotovi

Export: `build/web/index.html` (57 MB pck), pokrenut u headless Chromiumu.

| Screenshot | Šta pokazuje |
|---|---|
| `captures/tour_00_spawn.png` | spawn, Vlado sa M48, HUD oružja |
| `captures/tour_01_krupa_valley.png` | Krupa Valley |
| `captures/tour_02_crnca_village.png` | Crnča — kapela, kafana, čardak |
| `captures/tour_03_axis_checkpoint.png` | **stražarnica, barake, blokovi** |
| `captures/tour_04_durmitor_hideout.png` | Durmitor skrovište |
| `captures/tour_05_canyon_crossings.png` | kanjon, šuma |
| `captures/tour_06_lovcen_peaks.png` | **kameni katun, visoravan** |
| `captures/w2_mp40.png` | M48 u ruci, `RifleReadyIdle`, RIFLE ON |

### 3.3 Očuvanje Stage 3.2

| Fajl | Provjera |
|---|---|
| `player/player_controller.gd` | CRC OK, **nije mijenjan** |
| `player/player_camera.gd` | CRC OK, **nije mijenjan** |
| `player/player_animator.gd` | CRC OK, **nije mijenjan** |
| `scripts/weapon_controller.gd` | CRC OK, **nije mijenjan** |
| `characters/vlado/vlado_character.tscn` | CRC OK, **nije mijenjan** |
| `animations/vlado_locomotion.tres` | CRC OK, 19 klipova |
| `animations/vlado_fps.tres` | CRC OK, 10 klipova |

`audio/sound_manager.gd` je **proširen** (dodate 2 metode + 2 zvuka),
ali nijedna postojeća metoda nije izmijenjena.

`terrain/montenegro_terrain_data.gd` je **proširen** Stage 4 terasama
(6 ravnih platformi + 5 koridora). Originalna logika visine ostaje ista
za centralnu kotlinu — provjereno da je Krupa Valley ostala na 1,8 m / 4,5°.

---

## 4. NOVI FAJLOVI

```
stage33/
├── weapon_def.gd            podaci o jednom oružju
├── weapon_arsenal.gd        lista oružja, modeli, paljba, zamjena
├── arsenal_hud.gd           HUD: oružje u ruci, municija, slotovi
├── weapon_pickup.gd         preuzimanje oružja u svijetu (tipka F)
├── stage33_bootstrap.gd     montaža sistema + debug pickupi
└── validate_weapon_models.gd  validacija GLB-ova (trouglovi, dimenzije)

stage4/                       ← prenesen iz prethodne faze
├── world/                   6 regija, terase, rijeka, vegetacija, streamer
├── props/                   materijali, zgrade, interijeri
├── interaction/             vrata, bilješke, pickupi, dijalog
├── ui/                      Stage 4 HUD
└── stage4_bootstrap.gd      montaža svijeta

core/stage4_ledger.gd        autoload: bilješke, statistika
tools/make_weapon_textures.py  generator tekstura
tools/serve_web.py, *.js     Web test harness
```

---

## 5. KONTROLE

### Postojeće (Stage 3.2, nepromijenjeno)
`WASD` kretanje · `E`/`TAB` TPS↔FPS · `LMB` puca · `RMB` nišanjenje ·
`R` punjenje · `Shift` sprint · `Ctrl` čučanj · `Space` skok

### Novo (Stage 3.3)
| Tipka | Akcija |
|---|---|
| `Q` | zamjena oružja |
| `F` | preuzmi oružje sa postolja |

> `E` je već zauzet za TPS/FPS prebacivanje u `player_controller.gd:250`,
> zato preuzimanje ide na `F`.

### Novo (Stage 4, debug)
| Tipka | Akcija |
|---|---|
| `F5`–`F10` | teleport u 6 regija |
| `G` | interakcija / zatvori bilješku |

---

## 6. PERFORMANSE (za Galaxy S25 Ultra)

| Stavka | Vrijednost | Ocjena |
|---|---|---|
| MG42 model | 58.097 trouglova, 3 materijala | ✔ prihvatljivo |
| Mauser model | 27.630 trouglova, 5 materijala | ✔ prihvatljivo |
| Vanjska šuma | 937 stabala, MultiMesh, 64 bucketa | ✔ |
| `visibility_range` na šumi | 460 m | ✔ |
| Regija | 6, streaming ACTIVE 280 / MID 520 / FAR | ✔ |
| Teren | 4×4 chunk, postojeći iz Stage 3.2 | ✔ |
| **Occlusion culling** | isključen u Web buildu | ⚠ treba uključiti za Android |
| **LOD** | samo distance-based, nema mesh LOD | ⚠ |

---

## 7. SLJEDEĆI KORACI (po prioritetu)

1. **Pošalji `mp40.glb`** — jedan fajl, bez arhive (najbrže rješenje)
2. **Neprijatelji** — `stage4/actors/`: post-ratne patrolne/pretresne snage + očuvani patrol AI + pucanje
3. **Mission flow** — povezati 6 bilješki u zadatke sa ciljem
4. **FPS modeli** — `BoneAttachment3D` na FPS skelet
5. **Vodopadi** — kanjon + slap kod sjeverozapadne litice
6. **Android build** — export preset + occlusion culling + LOD

---

## 8. SIGURNOSNE KOPIJE

```
backups/stage3_2_baseline_20261111.tar.gz      16 MB  (čista Stage 3.2)
backups/vlado_stage33_initial_20261111.tar.gz  31 MB  (prije Stage 3.3)
vlado_stage33_STAGE33_STAGE4.zip               ← finalna arhiva ove faze
```

**Ništa nije obrisano** osim `weapons/` koji je bio identična kopija
`scripts/` (isti `weapon_controller.gd` byte-za-byte, nigdje referenciran)
i rušio je import zbog dvostrukog `class_name WeaponController`.
