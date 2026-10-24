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
- The "Why this is yours" explainer uses Apple Foundation Models on-device to word the target explanation. The numbers always come from `GoalEngine`; the model's answer is discarded unless every number in it appears in the facts we supplied, and a built-in personalised explanation is shown instead (also on devices without Apple Intelligence). Nothing leaves the device.
- The after-workout coach message uses the same on-device, number-checked approach (`OnDeviceWriter` + `Grounding`), with a built-in fallback. Nothing leaves the device.
- **Coach chat** keeps multiple sessions on-device (new / delete). Replies prefer Apple Foundation Models when available, grounded in a local context pack (today’s macros, 7-day protein hits, weekly volume, insights, diet pref). If the model is unavailable or invents numbers, a rule-based answer is shown instead. Chats are never uploaded.
- Export is a local JSON share sheet. Delete-all returns you to onboarding (seed foods/exercises remain).
- **No iCloud sync in Phase 1** (planned Phase 2).

## Formulas

| Piece | Method |
|--------|--------|
| BMR | Mifflin-St Jeor, or Katch-McArdle when body fat % or lean mass is provided (both optional) |
| TDEE | BMR × activity (1.2 / 1.375 / 1.5 / 1.65 / 1.8) |
| Calories | TDEE − 10 / 15 / 20% to lose, + 5 / 10 / 15% to gain (gentle / steady / ambitious); loss capped near 1% of body weight per week |
| Safety floor | 1200 kcal (female), 1500 (male), 1350 (other); never above maintenance for a loss goal; under 18 gets maintenance instead of a deficit |
| Protein | ~0.9–1.4 g/kg to maintain, 1.2–1.8 g/kg to lose or gain, on lean mass / adjusted weight for heavier bodies; +10% veg/Jain, +5% eggetarian; capped at 35% of calories |
| Fat | ~27% of calories, at least 0.6 g/kg |
| Carbs | Remainder, keeping at least 30% of calories; macros always add up to the target |
| Fiber | 14 g per 1000 kcal, at least 25 g |
| Water | ~35 ml/kg plus an activity bonus, shown in 250 ml glasses |
| Strength e1RM | Epley: `weight × (1 + reps/30)` |

Several constants (activity multipliers, protein g/kg, diet bumps) are judgment calls inside published ranges, flagged in `GoalEngine.swift` and `Enums.swift`. Estimates for everyday use, not medical advice.

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

Implementation: `PhotoNutritionEstimating` + `FoundationModelsPhotoNutritionEstimator` (multimodal image attachment + guided generation; JSON parse fallback).

## App Intents (Siri)

- Remaining calories  
- Remaining protein  
- Start named workout template (opens guidance to the matching template)

## Architecture

Feature / Domain / Data (MVVM ViewModels). Unit tests cover GoalEngine, diary totals, weekly muscle volume, PR detection, and photo confirm mapping.

## Coach chat

1. Coach tab → **Start a chat** or **New chat** (toolbar).
2. Ask free-form or tap a quick prompt (calories, protein, volume, meal ideas).
3. Badge shows **On-device** when Foundation Models wrote the reply, otherwise **Basic answers**.
4. Swipe / menu → **Delete chat**. Delete-all data in Settings also clears chats.

Implementation: `CoachChat` (facts + rules) + `CoachChatService` + `OnDeviceWriter` / `Grounding`. Models: `CoachChatSession`, `CoachChatMessage`.

## Phase 2 (not blocking MVP)

- Richer multimodal photo mapping to seed foods  
- Widgets, optional iCloud sync, barcode, Hindi labels, Live Activity rest timer  

## Explicit out of scope

Android, social feed, cloud LLM/vision, trainer marketplace, ads, subscriptions blocking core, medical condition management.

## Bundle

- Display name: **NutriLift India**  
- Bundle ID: `com.nutrilift.india`
