# Integracija 3D resursa

Ovaj projekat koristi kurirani katalog iz
[devanshutak25/3d-resources](https://github.com/devanshutak25/3d-resources/tree/main).
Sljedeći izvori su odabrani za Vlado-5:

| Izvor | Namjena | Licence / napomena |
|---|---|---|
| [Poly Haven](https://polyhaven.com/) | PBR teren, kamen, drvo i HDRI | CC0; provjeriti i sačuvati licencu svakog seta |
| [Mixamo](https://www.mixamo.com/) | Mocap i test karakteri | Besplatno; provjeriti trenutne uslove Adobea prije distribucije |
| [ActionForge](https://actionforge.app/) | Alternativni GLB rig/animation pipeline | Besplatno i CC0 biblioteka |
| [Godot Game Tools](https://viniguerrero.itch.io/godot-game-tools) | Mixamo → Godot Blender pipeline | Besplatno; instalirati samo u proizvodnom workflow-u |
| [Terrain3D](https://github.com/TokisanGames/Terrain3D) | Budući in-editor teren umjesto proceduralnih chunkova | Open source; zahtijeva GDExtension i Android build provjeru |
| [ProtonScatter](https://github.com/HungryProton/scatter) | Proceduralno rasipanje propova i vegetacije | Open source; prvo testirati GLB koristi i Mobile batchovanje |
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | Misije, razgovori i logove oznaka | Open source; plug-in se ne mora uvezivati u runtime bez potrebe |
| [TrenchBroom](https://trenchbroom.github.io/) | Brzi level blockout za kontrolisane oblasti | Open source; eksportovati u glTF/map import pipeline |
| [World Machine](https://www.world-machine.com/) | Generisanje heightmapa i maski terena | Freemium; licencirati planirane komercijalne eksport-e |

## Već integrisano

- `brown_mud_02`: PBR albedo, normal i roughness za dirt-road teren.
- `rock_01`: PBR albedo, normal i roughness za teren i proceduralne stijene.
- `old_stone_wall`: PBR albedo, normal i roughness za kamene kuće i zidine.
- `pine_bark`: PBR bark tekstura za buduće drvo i vegetaciju.
- `grass_ground`: PBR trava i zemlja za otvorene travnate zone.
- `forest_ground_04`: PBR šumska podloga za šumske zone.
- `autumn_field_2k.hdr`: opcioni 2K panoramski CC0 enviroment map.

Sve teksture su smještene u `assets/materials/polyhaven/`.
Licence su sačuvane uz lokalne fajlove.

## Pravila integracije

1. Koristiti samo download-izvore sa eksplicitnom licencom i sačuvati izvor/licencu.
2. Proveriti SVG, GLB i GDScript fajlove prije runtime integracije.
3. Za Android prvo provjeriti veličinu, mipmape i VRAM.
4. Ne zamijeniti originalni Vlado rig ili animacije bez odvojenog import testa.
5. GDExtension plug-inove instalirati u posebnu proverenu granu i testirati desktop/Android build.
