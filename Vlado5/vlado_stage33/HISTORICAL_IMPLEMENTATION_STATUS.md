# Status historijske migracije

## Potvrđeno u kodu

- Aktivni protivnik je zamijenjen klasom `PostWarEnemy`.
- U Spawneru postoje zasebni profili `partizan`, `ozna` i `udba`.
- Svi aktivni spawneri koriste periodne boje uniforme i fazno prilagođene parametre.
- OZNA i UDBA šalju dojave obližnjim protivnicima nakon otkrivanja.
- Glavni Vlado model i njegove `vlado_locomotion.tres` / `vlado_fps.tres` biblioteke nisu zamijenjeni.
- Misije imaju oznaku fikcionalnog scenarija kada prikazuju izmišljene zapise.
- APK nije kreiran tokom razvoja.

## Testirano

- Godot headless editor scan i class registration prolaze.
- Main scene učitava, uz montažu teritorija, Stage33 arsenala i Stage4 garnizona.
- Headless smoke test nije prijavio GDScript parser greške.
- Live Vulkan pokretanje na virtualnom displeju radi, ali je zvuk pao na dummy audio zbog hosta.

## U razvoju

- Screenshot serija iz stvarnog gameplay viewporta još nije završena u ovom headless okruženju.
- Potreban je naredni live snapshot na monitoru ili Android uređaju.
- Dokumentacija i 3D modeli suzbijaju njemačke identitete u aktivnom gameplayu.
