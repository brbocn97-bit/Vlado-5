# MODELI — Vlado: The Last Outlaw

Tvoji modeli, optimizovani. **55 modela**, svi validni (0 grešaka).

## Šta je unutra

```
zgrade/       7 modela    kuca_kamena, kuca_brvnara, supa_drvarnica,
                          kola, stalka, znak, avion_olupina
vegetacija/  10 modela    bor, hrast_zeleni, hrast_zuti, zbun, paprat,
                          razlicak, bijeli_cvijet, grana_hrast, grana_bor...
oprema/      13 modela    balvan_veliki, balvan_mali, drvena_bure,
                          metalna_bure, sanduk, stijena_1-4, vatra,
                          lezaljka, saksija, sjekira
teren/       25 modela    put_zemljani, put_goli, put_staze, put_ivica,
                          kaldrma, trava_zelena, trava_suha, trava_visoka,
                          trava_blizu, sibljak, litica, stijene, zemlja,
                          lisce, lokva, ograde, stablo_breza, stablo_hrast...
```

## Kako je optimizovano

| Original | Rezultat | Kako |
|---|---|---|
| kuca1.glb **52 MB** | **7,8 MB** | 1M trouglova → 17k, teksture 1024px |
| kucasasumom2.glb **38 MB** | **razbijen na 31 objekat** | 20 tekstura 1024px, 512px za sitno |
| road.glb **89 MB** | **razbijen na 25 objekata** | teksture 512px |

**Ukupno: 180 MB → 84 MB (−53%)**

Geometrija nije dirana osim gdje je bila apsurdna (1 000 000 trouglova za jednu kuću).

Teksture:
- zgrade: 1024 px, JPEG q92
- vegetacija: 768 px, JPEG q90
- oprema i teren: 512 px, JPEG q88
- normal mape ostaju PNG (JPEG bi ih pokvario)

## Kako ih ubaciti u projekat

### 1. Raspakuj

```bash
cd "/storage/emulated/0/Igrica vlado/projekt3"
unzip -o ~/storage/downloads/MODELI_v1.zip -d assets/models/
```

Dobićeš:
```
assets/models/zgrade/
assets/models/vegetacija/
assets/models/oprema/
assets/models/teren/
```

### 2. Otvori Godot

**Import** → `project.godot` → **Import & Edit**

Godot će uvesti sve modele. Traje **5–10 min** za 55 modela.

### 3. Koristi ih

U kodu:

```gdscript
# jedan model
var kuca = load("res://assets/models/zgrade/kuca_kamena.glb").instantiate()
add_child(kuca)

# šuma preko MultiMesh (mnogo brže od 14000 čvorova)
var bor = load("res://assets/models/vegetacija/bor.glb")
```

## Kako da ih zamijenim u kodu

Ako želiš da postojeće proceduralne kuće zamijeniš pravim modelima:

```gdscript
# stage4/world/region_krupa_valley.gd
# umjesto Stage4Buildings.make_house(...) koristi:
var scene := load("res://assets/models/zgrade/kuca_kamena.glb")
var inst := scene.instantiate()
place(inst, HOMESTEAD.x, HOMESTEAD.y, 0.05)
```

Reci mi ako želiš da to uradim — znam gdje su sve zamjene.

## Napomene

- **kuca_kamena** je 7,8 MB i 17 000 trouglova. Za kuću je to mnogo ali izgleda dobro. Ako zapne na telefonu, mogu je dodatno pojednostaviti.
- **teren/** modeli su veliki (48 MB) jer imaju teksture visoke rezolucije. Njih koristi štedljivo — po jedan primjerak, ne 1000 puta.
- **trava_zelena** i **trava_suha** su 4,9 MB / 3,5 MB — za travu je bolje koristiti postojeći MultiMesh sistem sa malom teksturom.

## Provjereno

Svi modeli prošli `gltf-transform validate`:
- ✅ 55/55 bez grešaka
- ✅ geometrija netaknuta
- ✅ teksture čitljive
- ✅ sampler reference ispravne
- ✅ ekstenzije deklarisane
