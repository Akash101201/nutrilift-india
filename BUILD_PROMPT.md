# NutriLift India — Compromise Build Prompt

Copy everything below the line into an AI coding agent to build the app.

---

Build a privacy-first, free, offline-capable iOS fitness app (working name: NutriLift India).

## Product summary

Help Indian users track food (Indian cuisine first), hit calorie/macro goals for lose/maintain/gain, log workouts, see weekly/monthly progress by exercise and muscle group, and get simple coaching insights. Privacy and zero cost for core features are non-negotiable. No backend, no account, no ads, no selling data.

## Hard constraints

1. SwiftUI + SwiftData + HealthKit + Swift Charts + App Intents.
2. No mandatory login. All user health data on-device by default.
3. No third-party cloud LLMs, vision APIs, ad SDKs, or external food-recognition ML.
4. Photo → calorie/macro estimate: Apple Foundation Models / Apple Intelligence ONLY, on-device, when available. If unavailable, disable photo estimate and keep manual logging. Never fall back to non-Apple ML/cloud.
5. Chat coach: prefer on-device Foundation Models grounded in local user data; if unavailable, use rule-based / FAQ fallback. Never call OpenAI/etc.
6. Free forever for core logging + insights. No paywall on basics.
7. Not medical advice; block extreme diet advice; soft-warn very low calorie targets.

## Phase 1 — build this fully (Definition of Done)

### Onboarding

- Paged, one-question-per-screen flow with emoji choices. Collect age, sex, height, weight, activity, goal (lose/maintain/gain) with pace (gentle/steady/ambitious), diet pref (veg/eggetarian/non-veg/Jain/custom). Optional "Fine-tune" step for body fat % or lean mass, easy to skip.
- Compute BMR (Mifflin-St Jeor, or Katch-McArdle with body composition), TDEE, calorie target (percentage of TDEE by pace, sex-specific floors, under-18 rule), macros (protein g/kg on lean/adjusted weight with diet adjustment; fat ~27%; carbs remainder), fiber and water.
- Show a "Why these numbers?" explainer and an accuracy meter; allow full manual override of targets.
- HealthKit optional (steps, active energy, workouts, body mass). App works if denied.
- Offline-capable; privacy promise on first screen.

### Food (Indian-first)

- Seed ≥300 Indian foods with English names + common transliterations; servings in g/piece/katori/plate/glass; calories + P/C/F; source/confidence tags.
- Search, recent, favorites, meal templates, custom foods.
- Diary by meal type; copy yesterday; Today totals live.
- Store macro snapshot on each diary entry.
- Logging path for “2 roti + dal + sabzi” via favorites/recents must be fast.

### Today dashboard

- Calories + macros remaining, steps vs target, exercise estimate, water, streak, a weight log (latest weight, 30-day trend, quick log with optional Apple Health import and an "update your targets?" prompt on big changes), and a workout card (start empty, start a routine, or resume).
- Label burn/net calories as estimates.

### Workouts

- Seed ≥80 exercises (muscle groups, equipment). Users can create, edit and delete their own custom exercises.
- Starter routines (Full Body A/B, PPL or Upper/Lower) plus user-built routines: create from scratch, duplicate a starter to customise it, or save a finished workout as a routine.
- Start an empty workout or a routine from Workouts or Today. The live workout is laid out like popular lifting apps: per-exercise table with SET / PREVIOUS (last time, tap to reuse) / KG / REPS / ✓, add or swipe-delete sets, add exercises on the fly, rest timer, notes, minimise and resume. A workout is saved as it goes; finishing keeps only ticked sets.
- Per-exercise progress: personal bests, estimated 1RM / heaviest / volume charts, and full history, for built-in and custom exercises.
- PRs + history + repeat workout. A "PR" must beat earlier sessions and earlier sets this session; a first-ever set is a baseline, not a record.
- After finishing: a summary with duration, volume, sets and records, what was done (compared with last time), and next-time suggestions from simple progressive-overload rules. A coach message appreciating the effort and recapping it is written on-device by Apple Foundation Models. Its answer is discarded unless every number in it appears in the facts supplied, with a built-in message as fallback.
- Weekly sets per muscle group aggregation.

### Progress

- Weight chart (ranges: 7D/4W/3M…).
- Per-exercise strength trend.
- Muscle-group weekly volume.
- Nutrition adherence (e.g. protein hit rate).
- Empty states with CTAs.

### Insights (rule-based in Phase 1)

At least 8 rules, explainable with user numbers, non-shaming. Examples:

- Protein under target ≥3/7 days → Indian high-protein suggestions by diet pref.
- Muscle volume drop >25% vs 4-week avg.
- Stall on an exercise → suggest small progression or deload.
- Large deficit + hard training → recovery note.

### Coach + Siri (Phase 1 stubs that work)

- Coach tab: rule-based Q&A for remaining calories/protein, weekly volume, simple meal ideas; stub Foundation Models chat behind availability check.
- App Intents: remaining calories, remaining protein, start a named workout template.
- UI badge: “On-device” vs “Basic answers (AI unavailable)”.

### Photo food log (Phase 1 architecture only)

- Define protocol `PhotoNutritionEstimating`.
- ONLY implementation: Apple Foundation Models estimator (gated).
- UI: entry point disabled with clear message if unsupported.
- Never auto-save estimates; user must confirm/edit.
- Full photo UX can complete in Phase 2, but protocol + gate must exist in Phase 1.

### Settings

- Edit profile/targets/diet/units.
- Local notifications optional (off or gentle; local only).
- Export all data JSON; Delete all data → back to onboarding.
- Disclaimer + “About calculations” (formulas + food estimate caveats).
- No iCloud sync in Phase 1 (document as Phase 2).

### Quality bar

- MVVM (or clear Feature/Domain/Data split).
- Unit tests: BMR/TDEE/macros (including pace, floors, protein basis, body-composition inputs, validation), streaks and water totals, diary totals, weekly muscle volume, PR detection.
- Info.plist HealthKit usage strings accurate.
- README: how to run, privacy model, formulas, seed data notes, Phase 2 plan.
- Works offline after first launch; builds for iOS Simulator.

## Phase 2 — implement after Phase 1 DoD (scaffold OK, don’t block MVP)

- Full photo meal estimate UX via Foundation Models only; map to local foods; edit-before-save; “photo not uploaded” badge; default discard photo after log.
- Richer on-device chat using local context pack (today + last 7 days nutrition, targets, recent workouts, diet pref).
- Widgets; optional iCloud sync toggle; barcode; Hindi labels; Live Activity rest timer.

## Explicit out of scope

Android, social/feed, cloud LLM/vision, trainer marketplace, ads, subscriptions blocking core, medical condition management.

## UX tone

Fast logging over flashy UI. Encouraging, direct, no shame. Indian household units. Dynamic Type. Clean native look (avoid generic purple-glow AI aesthetic).

## Defaults if unsure

Choose sensible defaults, document in README, keep going. Prefer shipping Phase 1 complete over partial Phase 2 polish.

## Start order

1. Xcode project structure + SwiftData models
2. Seed foods/exercises/templates
3. Onboarding + goal engine
4. Food diary + Today
5. Workouts + Progress charts
6. Rule-based insights + App Intents
7. Foundation Models stubs (chat + photo protocol)
8. Export/delete + tests + README

Deliver Phase 1 to Definition of Done above.
