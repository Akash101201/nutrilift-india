#!/usr/bin/env python3
"""Merge the curated gym list with free-exercise-db.

Source: https://github.com/yuhonas/free-exercise-db (Unlicense).
Names and instructions only. Demonstration images are not included.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENDOR = Path(__file__).resolve().parent / "vendor" / "free-exercise-db.json"
OUT = ROOT / "NutriLiftIndia" / "NutriLiftIndia" / "Resources" / "Seed" / "exercises.json"

MUSCLE = {
    "abdominals": "core",
    "abductors": "glutes",
    "adductors": "legs",
    "biceps": "biceps",
    "calves": "legs",
    "chest": "chest",
    "forearms": "biceps",
    "glutes": "glutes",
    "hamstrings": "legs",
    "lats": "back",
    "lower back": "back",
    "middle back": "back",
    "neck": "fullBody",
    "quadriceps": "legs",
    "shoulders": "shoulders",
    "traps": "shoulders",
    "triceps": "triceps",
}

EQUIPMENT = {
    "barbell": "barbell",
    "dumbbell": "dumbbell",
    "body only": "bodyweight",
    "cable": "cable",
    "machine": "machine",
    "kettlebells": "kettlebell",
    "bands": "band",
    "e-z curl bar": "barbell",
    "medicine ball": "other",
    "exercise ball": "other",
    "foam roll": "other",
    "other": "other",
}

# Curated id -> free-exercise-db id, when the names differ but the movement is the same.
ALIASES = {
    "ex_bench_press": "Barbell_Bench_Press_-_Medium_Grip",
    "ex_pushup": "Pushups",
    "ex_cable_fly": "Flat_Bench_Cable_Flyes",
    "ex_chest_press_machine": "Leverage_Chest_Press",
    "ex_dip": "Dips_-_Chest_Version",
    "ex_pullup": "Pullups",
    "ex_barbell_row": "Bent_Over_Barbell_Row",
    "ex_lat_pulldown": "Wide-Grip_Lat_Pulldown",
    "ex_deadlift": "Barbell_Deadlift",
    "ex_ohp": "Standing_Military_Press",
    "ex_lateral_raise": "Side_Lateral_Raise",
    "ex_db_curl": "Dumbbell_Bicep_Curl",
    "ex_skull_crusher": "EZ-Bar_Skullcrusher",
    "ex_close_grip_bench": "Close-Grip_Barbell_Bench_Press",
    "ex_squat": "Barbell_Squat",
    "ex_front_squat": "Front_Barbell_Squat",
    "ex_hip_thrust": "Barbell_Hip_Thrust",
    "ex_crunch": "Crunches",
    "ex_ab_wheel": "Barbell_Ab_Rollout",
    "ex_farmer_carry": "Farmers_Walk",
    "ex_smith_bench": "Smith_Machine_Bench_Press",
    "ex_upright_row": "Upright_Barbell_Row",
    "ex_arnold_press": "Arnold_Dumbbell_Press",
    "ex_back_extension": "Hyperextensions_Back_Extensions",
    "ex_box_jump": "Front_Box_Jump",
    "ex_row_erg": "Rowing_Stationary",
    "ex_treadmill": "Running_Treadmill",
}

MUSCLES = {
    "chest", "back", "shoulders", "biceps", "triceps", "legs", "glutes", "core", "fullBody", "cardio",
}
EQUIPMENTS = {
    "bodyweight", "dumbbell", "barbell", "machine", "cable", "kettlebell", "band", "other",
}


def norm(name: str) -> str:
    text = name.lower().replace("-", " ").replace("/", " ")
    text = re.sub(r"[^a-z0-9 ]", "", text)
    return re.sub(r"\s+", " ", text).strip()


def singular_key(name: str) -> str:
    parts = norm(name).split()
    if not parts:
        return ""
    last = parts[-1]
    if last.endswith(("ches", "shes", "xes", "zes", "sses")) and len(last) > 4:
        last = last[:-2]
    elif last.endswith("s") and not last.endswith("ss") and len(last) > 3:
        last = last[:-1]
    parts[-1] = last
    return " ".join(parts)


def clean_steps(steps: list[str]) -> list[str]:
    cleaned = []
    for step in steps:
        text = " ".join(step.split())
        if text:
            cleaned.append(text)
    return cleaned


def map_muscle(entry: dict) -> str:
    if entry.get("category") == "cardio":
        return "cardio"
    primary = entry.get("primaryMuscles") or []
    if not primary:
        return "fullBody"
    return MUSCLE.get(primary[0], "fullBody")


def map_equipment(entry: dict) -> str:
    raw = entry.get("equipment") or ""
    return EQUIPMENT.get(raw, "other")


def fedb_seed_id(source_id: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", source_id.lower()).strip("_")
    return f"fedb_{slug}"


def load_catalog() -> list[dict]:
    if not VENDOR.exists():
        sys.exit(f"Missing {VENDOR}. Download dist/exercises.json from free-exercise-db.")
    data = json.loads(VENDOR.read_text(encoding="utf-8"))
    if not isinstance(data, list) or not data:
        sys.exit("free-exercise-db file is empty")
    return data


def write_exercises() -> list[dict]:
    from generate_seeds import EXERCISES

    catalog = load_catalog()
    by_id = {entry["id"]: entry for entry in catalog}
    missing = [source for source in ALIASES.values() if source not in by_id]
    if missing:
        sys.exit("Alias ids missing from free-exercise-db: " + ", ".join(missing))

    by_key: dict[str, list[dict]] = {}
    for entry in catalog:
        by_key.setdefault(singular_key(entry["name"]), []).append(entry)

    used: set[str] = set()
    rows: list[dict] = []

    for seed_id, name, muscle, equipment in EXERCISES:
        match = None
        alias = ALIASES.get(seed_id)
        if alias:
            match = by_id[alias]
        else:
            candidates = by_key.get(singular_key(name), [])
            if len(candidates) == 1:
                match = candidates[0]
        instructions: list[str] = []
        if match is not None:
            if match.get("category") == "stretching" and "stretch" not in name.lower():
                sys.exit(f"Refusing to attach a stretch to {seed_id} ({name})")
            used.add(match["id"])
            instructions = clean_steps(match.get("instructions") or [])
        rows.append({
            "id": seed_id,
            "name": name,
            "muscleGroup": muscle,
            "equipment": equipment,
            "instructions": instructions,
        })

    extras = []
    for entry in catalog:
        if entry["id"] in used:
            continue
        extras.append({
            "id": fedb_seed_id(entry["id"]),
            "name": entry["name"],
            "muscleGroup": map_muscle(entry),
            "equipment": map_equipment(entry),
            "instructions": clean_steps(entry.get("instructions") or []),
        })
    extras.sort(key=lambda row: row["name"].lower())
    rows.extend(extras)

    ids = [row["id"] for row in rows]
    if len(ids) != len(set(ids)):
        sys.exit("Duplicate exercise ids")
    for row in rows:
        if row["muscleGroup"] not in MUSCLES or row["equipment"] not in EQUIPMENTS:
            sys.exit(f"Bad mapping for {row['id']}: {row['muscleGroup']} {row['equipment']}")

    curated_ids = {item[0] for item in EXERCISES}
    if not curated_ids <= set(ids):
        sys.exit("A curated exercise id was dropped")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    with_steps = sum(1 for row in rows if row["instructions"])
    print(f"Wrote {len(rows)} exercises ({with_steps} with instructions) -> {OUT}")
    return rows


if __name__ == "__main__":
    write_exercises()
