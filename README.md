# Gym Plan (iOS)

SwiftUI aplikacija za planove treninga: planovi → rutine → vežbe, superseti, aktivni trening sa tajmerom odmora, statistika i uvoz iz Excel-a.

## Kako se pravi .ipa

Build radi GitHub Actions na Mac serveru (`.github/workflows/build.yml`):

1. Svaki push na `main` (ili **Actions → Build IPA → Run workflow**) pokreće build. Traje oko 10–15 minuta.
2. Workflow skida bazu vežbi [free-exercise-db](https://github.com/yuhonas/free-exercise-db) (javni domen), smanjuje slike, generiše Xcode projekat (XcodeGen) i pravi nepotpisan `GymPlan.ipa`.
3. Gotov fajl je u **Releases** (desno na stranici repoa) kao `GymPlan.ipa`, i u samom run-u pod **Artifacts**.

Ako build padne: otvori neuspeli run u **Actions**, skini artifact `build-log` (ili kopiraj crvene `error:` linije) i pošalji ih Claude-u.

## Instalacija u LiveContainer

1. Na iPhone-u u Safari-ju otvori **Releases** ovog repoa i skini `GymPlan.ipa`.
2. Otvori LiveContainer → **+** (gore desno) → izaberi `GymPlan.ipa`.
3. Long-press na aplikaciju → **Settings** → uključi **Fix Local Notifications**.
4. Prvi put kad pokreneš trening, dozvoli notifikacije.

## Kontrola treninga sa zaključanog ekrana

- **Instalacija preko SideStore / AltStore / Sideloadly:** Live Activity kartica na zaključanom ekranu i u Dynamic Island-u (vežba, ukupni tajmer, set, +/− ponavljanja, +/− kg, X / odmor / Done).
- **LiveContainer:** ne pokreće app extensions, pa umesto kartice ide notifikacija sa akcijama Done / Skip / −1 rep / Edit.

Aplikacija sama bira način; trenutni se vidi u Settings → Notifications → Lock screen controls.

## Uvoz iz Excel-a

Settings → **Import from Excel / CSV**. Šablon: `docs/GymPlan_import_template.xlsx`.

| Routine | Exercise | Rest | Set 1 | Set 2 | Set 3 |
|---|---|---|---|---|---|
| Upper | Barbell Bench Press - Medium Grip | 1:30 | 10x60 | 8x65 | 6x70 |
| Upper | Pullups | 2:00 | 8 | 8 | 6 |
| Lower | Plank | 60 | 1 min | 1 min | |
| Cardio | Running, Treadmill | | 20 min 3000 m | | |

- Set ćelija: `10x60` (ponavljanja × kg), `12` (bez tega), `1 min`, `30 s`, `400 m`, `5 km`.
- Rest: `90`, `1:30`, `2 min`, prazno = Off.
- Vežbe se traže po imenu u bazi; nepoznata imena postaju custom vežbe.

## Struktura

```
project.yml                 XcodeGen projekat (iOS 17+)
GymPlan/App                 ulaz u aplikaciju, tema, formatiranje
GymPlan/Models              Plan, Routine, Exercise, istorija, aktivni trening
GymPlan/Store               čuvanje podataka (JSON u Documents)
GymPlan/Workout             tok treninga, notifikacije, Live Activity, zvuk za kraj odmora
GymPlanWidgets              widget extension: Live Activity kartica
Shared                      kod zajednički za app i extension (ActivityAttributes, App Intents)
GymPlan/Import              čitanje .xlsx / .csv
GymPlan/Views               ekrani
```

Podaci o vežbama i slike: free-exercise-db (Unlicense / javni domen).
