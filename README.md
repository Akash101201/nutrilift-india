# NutriLift India

Privacy-first, free, offline-capable iOS fitness app for Indian food logging, calorie/macro goals, workouts, progress, and simple coaching. **No backend, no account, no ads.**

Phase 1 source is ready to open on a Mac with Xcode. This repo was authored on Windows, so build/run happens on macOS.

## Requirements

- macOS with **Xcode 16+** (file-system synchronized project)
- iOS **17.0+** Simulator or device for core features
- **Apple Intelligence / Foundation Models** (iOS 26+ capable device) for photo food estimates and optional on-device coach badge path
- Apple Developer team selected in Xcode for HealthKit / device runs

## How to run

1. Copy or clone this repo onto a Mac.
2. Open [`NutriLiftIndia/NutriLiftIndia.xcodeproj`](NutriLiftIndia/NutriLiftIndia.xcodeproj).
3. Select the **NutriLiftIndia** target → Signing & Capabilities → choose your Team.
4. Run on an iPhone Simulator (or device).
5. Tests: `Product → Test` or  
   `xcodebuild -scheme NutriLiftIndia -destination 'platform=iOS Simulator,name=iPhone 16' test`

Regenerate seed JSON (optional):

```bash
python3 scripts/generate_seeds.py
```

## Privacy model

- All health, food, and workout data stored **on-device** with SwiftData.
- No login, analytics SDKs, ad SDKs, or NutriLift cloud API.
- HealthKit is **optional**; the app works if denied.
- Photo meal estimates use **Apple Foundation Models only**. Photos are **not uploaded**. After save, the in-memory photo is discarded. UI shows “Photo not uploaded.”
- Export is a local JSON share sheet. Delete-all returns you to onboarding (seed foods/exercises remain).
- **No iCloud sync in Phase 1** (planned Phase 2).

## Formulas

| Piece | Method |
|--------|--------|
| BMR | Mifflin-St Jeor |
| TDEE | BMR × activity (1.2–1.9) |
| Calories | TDEE + goal delta (−500 / 0 / +300), floor 800 kcal |
| Protein | g/kg by goal (lose 2.0, maintain 1.6, gain 1.8) |
| Fat | ~27.5% of calories |
| Carbs | Remainder |
| Strength e1RM | Epley: `weight × (1 + reps/30)` |

Soft-warn under 1200 kcal. Extreme auto-targets are floored — not medical advice.

## Seed data notes

Bundled under `NutriLiftIndia/NutriLiftIndia/Resources/Seed/`:

- `foods.json` — **320** Indian-first foods (English names + transliterations, household units, kcal/P/C/F, source/confidence). Core items are IFCT-inspired or estimated; generated regional variants are low-confidence placeholders for search coverage.
- `exercises.json` — **90** exercises with muscle group + equipment.
- `workout_templates.json` — Full Body A/B, Upper, Lower, Push, Pull (**6** templates).

Values are guides for logging, not lab assays.

## Photo food log

1. Food tab → **Estimate from photo** (disabled with explanation if Foundation Models unavailable).
2. Capture/choose image; optional **name** and **quantity** hints.
3. On-device estimate → **confirm/edit** name, quantity, unit, calories, and macros.
4. Save writes a diary entry with a macro snapshot (`source = photoEstimate`). Never auto-saves model output.

Implementation: `PhotoNutritionEstimating` + `FoundationModelsPhotoNutritionEstimator` only.

## App Intents (Siri)

- Remaining calories  
- Remaining protein  
- Start named workout template (opens guidance to the matching template)

## Architecture

Feature / Domain / Data (MVVM ViewModels). Unit tests cover GoalEngine, diary totals, weekly muscle volume, PR detection, and photo confirm mapping.

## Phase 2 (not blocking MVP)

- Richer multimodal photo mapping to seed foods  
- Fuller on-device coach with 7-day context pack  
- Widgets, optional iCloud sync, barcode, Hindi labels, Live Activity rest timer  

## Explicit out of scope

Android, social feed, cloud LLM/vision, trainer marketplace, ads, subscriptions blocking core, medical condition management.

## Bundle

- Display name: **NutriLift India**  
- Bundle ID: `com.nutrilift.india`
