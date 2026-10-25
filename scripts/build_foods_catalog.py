#!/usr/bin/env python3
"""
Build NutriLift foods.json from INDB (cooked recipes) + IFCT 2017 (ingredient staples).

Prereqs (already downloaded under scripts/data/raw/):
  - INDB.xlsx from https://github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB-
  - ifct-compositions.csv from the ifct2017 compositions export

Usage:
  python scripts/build_foods_catalog.py
  python scripts/generate_seeds.py   # regenerates templates/plans; keeps foods.json
"""
from __future__ import annotations

import csv
import json
import re
import unicodedata
from pathlib import Path

try:
    import openpyxl
except ImportError as exc:  # pragma: no cover
    raise SystemExit("pip install openpyxl") from exc

ROOT = Path(__file__).resolve().parents[1]
RAW = Path(__file__).resolve().parent / "data" / "raw"
OUT = ROOT / "NutriLiftIndia" / "NutriLiftIndia" / "Resources" / "Seed"
INDB_PATH = RAW / "INDB.xlsx"
IFCT_PATH = RAW / "ifct-compositions.csv"

# Stable seed ids used by meal templates / existing diaries.
# Prefer INDB recipe codes; IFCT codes use the ifct_ prefix in emit_ifct.
ALIAS_TO_INDB = {
    "roti_whole_wheat": "ASC096",       # Chapati/Roti
    "paratha_plain": "ASC097",          # Plain parantha
    "naan": "ASC142",
    "rice_cooked": "ASC113",            # Boiled rice
    "idli": "ASC144",
    "sambar": "ASC167",
    "curd_rice": "ASC126",
    "egg_bhurji": "ASC059",             # Scrambled egg / ande ki bhurji
    "boiled_egg": "ASC056",
    "dal_tadka": "ASC151",              # Washed moong dal (closest everyday dal)
    "mixed_veg_sabzi": "ASC193",        # Pea curry / matar sabzi (everyday sabzi)
    "masala_dosa": "ASC146",
    "uttapam": "ASC148",
    "poori": "ASC107",
}

# IFCT staples that INDB recipes don't cover well (oils, milk, fruits, paneer, atta).
# (ifct_code, stable_id, display_name, transliterations, unit, amount, grams)
IFCT_STAPLES = [
    ("T013", "ghee", "Ghee", [], "tablespoon", 1, 14),
    ("T006", "mustard_oil", "Mustard oil", [], "tablespoon", 1, 14),
    ("L002", "milk_full_fat", "Milk (cow, whole)", ["doodh"], "glass", 1, 250),
    ("L001", "milk_buffalo", "Milk (buffalo, whole)", ["doodh"], "glass", 1, 250),
    ("L003", "paneer_plain", "Paneer", ["cottage cheese"], "katori", 1, 100),
    ("M004", "egg_boiled_ifct", "Egg, boiled (IFCT)", ["anda"], "piece", 1, 50),
    ("A019", "atta", "Wheat flour (atta)", ["atta"], "gram", 100, 100),
    ("E012", "banana", "Banana (robusta)", ["kela"], "piece", 1, 100),
    ("E001", "apple", "Apple", ["seb"], "piece", 1, 150),
]

UNIT_MAP = {
    "bowl": "katori",
    "small bowl": "katori",
    "soup bowl": "katori",
    "curry bowl": "katori",
    "plate": "plate",
    "small plate": "plate",
    "dish": "plate",
    "casserole dish": "plate",
    "glass": "glass",
    "tall glass": "glass",
    "tea cup": "cup",
    "cup": "cup",
    "ice cream cup": "cup",
    "souffle cup": "cup",
    "tablespoon": "tablespoon",
    "piece": "piece",
    "slice": "piece",
    "large slice": "piece",
    "biscuit": "piece",
    "cookie": "piece",
    "triangle": "piece",
    "toasted triangle": "piece",
    "sandwich": "piece",
    "parantha": "piece",
    "chapati": "piece",
    "roti": "piece",
    "poori": "piece",
    "naan": "piece",
    "bhatura": "piece",
    "idli": "piece",
    "dosa": "piece",
    "uttapam": "piece",
    "egg": "piece",
    "omelette": "piece",
    "pancake": "piece",
    "cheela": "piece",
    "vada": "piece",
    "ladoo": "piece",
    "burfi": "piece",
    "cutlet": "piece",
    "kabab": "piece",
    "pastry": "piece",
    "tart": "piece",
    "pie": "piece",
    "jar": "piece",
}


def slug(text: str) -> str:
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return text[:48] or "food"


def parse_names(raw: str) -> tuple[str, list[str]]:
    """Split 'English (local / local)' into display name + transliterations."""
    raw = (raw or "").strip()
    m = re.match(r"^(.*)\((.*)\)\s*$", raw)
    if not m:
        return raw, []
    primary = m.group(1).strip(" /")
    alts = []
    for part in re.split(r"[/,]", m.group(2)):
        part = part.strip()
        if part and part.lower() != primary.lower():
            alts.append(part)
    return primary or raw, alts[:6]


def kj_to_kcal(kj: float) -> float:
    return kj / 4.184


def num(value) -> float | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    s = str(value).strip()
    if not s or s.lower() in {"na", "n", "tr", "none", "-", "."}:
        return None
    try:
        return float(s.replace(",", ""))
    except ValueError:
        return None


def map_unit(raw: str | None) -> str | None:
    if not raw:
        return None
    key = str(raw).strip().lower()
    if key in UNIT_MAP:
        return UNIT_MAP[key]
    # fuzzy
    for needle, unit in UNIT_MAP.items():
        if needle in key:
            return unit
    return "piece"


def food_row(
    seed_id: str,
    name: str,
    transliterations: list[str],
    unit: str,
    amount: float,
    grams: float,
    kcal: float,
    protein: float,
    carb: float,
    fat: float,
    source: str,
    confidence: str,
    fibre: float | None = None,
) -> dict:
    row = {
        "id": seed_id,
        "name": name,
        "transliterations": transliterations,
        "servingUnit": unit,
        "servingAmount": amount,
        "gramsPerServing": round(grams, 1),
        "calories": round(kcal, 1),
        "proteinG": round(protein, 2),
        "carbG": round(carb, 2),
        "fatG": round(fat, 2),
        "source": source,
        "confidence": confidence,
    }
    if fibre is not None:
        row["fiberG"] = round(fibre, 2)
    return row


def load_indb() -> list[dict]:
    if not INDB_PATH.exists():
        raise SystemExit(f"Missing {INDB_PATH}. Download INDB.xlsx into scripts/data/raw/")
    wb = openpyxl.load_workbook(INDB_PATH, read_only=True, data_only=True)
    ws = wb["Nutrient Data"]
    headers = None
    by_code: dict[str, dict] = {}
    rows_out: list[dict] = []

    for raw in ws.iter_rows(values_only=True):
        if headers is None:
            headers = {h: i for i, h in enumerate(raw)}
            continue
        code = str(raw[headers["food_code"]] or "").strip()
        name_raw = str(raw[headers["food_name"]] or "").strip()
        if not code or not name_raw:
            continue

        per100_kcal = num(raw[headers["energy_kcal"]]) or 0.0
        per100_p = num(raw[headers["protein_g"]]) or 0.0
        per100_c = num(raw[headers["carb_g"]]) or 0.0
        per100_f = num(raw[headers["fat_g"]]) or 0.0
        per100_fiber = num(raw[headers["fibre_g"]])

        unit_raw = raw[headers["servings_unit"]]
        unit_kcal = num(raw[headers["unit_serving_energy_kcal"]])
        unit_p = num(raw[headers["unit_serving_protein_g"]])
        unit_c = num(raw[headers["unit_serving_carb_g"]])
        unit_f = num(raw[headers["unit_serving_fat_g"]])
        unit_fiber = num(raw[headers["unit_serving_fibre_g"]])

        mapped = map_unit(str(unit_raw) if unit_raw else None)
        use_unit_serving = (
            mapped is not None
            and unit_kcal is not None
            and unit_kcal >= 5
            and not (mapped == "piece" and unit_kcal > 700)
        )

        if use_unit_serving:
            grams = (unit_kcal / per100_kcal * 100.0) if per100_kcal > 1 else 100.0
            kcal, protein, carb, fat = unit_kcal, unit_p or 0.0, unit_c or 0.0, unit_f or 0.0
            fiber = unit_fiber
            unit = mapped
            amount = 1.0
            confidence = "high"
        else:
            # Fall back to per-100 g.
            grams = 100.0
            kcal, protein, carb, fat = per100_kcal, per100_p, per100_c, per100_f
            fiber = per100_fiber
            unit = "gram"
            amount = 100.0
            confidence = "medium" if per100_kcal > 0 else "low"

        display, alts = parse_names(name_raw)
        seed_id = f"indb_{code.lower()}"
        row = food_row(
            seed_id=seed_id,
            name=display,
            transliterations=alts,
            unit=unit,
            amount=amount,
            grams=grams,
            kcal=kcal,
            protein=protein,
            carb=carb,
            fat=fat,
            source="INDB",
            confidence=confidence,
            fibre=fiber,
        )
        row["_indb_code"] = code
        by_code[code] = row
        rows_out.append(row)

    # Attach stable aliases (copy macros, keep friendly id).
    aliased: list[dict] = []
    used_codes: set[str] = set()
    for stable_id, code in ALIAS_TO_INDB.items():
        src = by_code.get(code)
        if not src:
            print(f"warn: alias {stable_id} -> {code} not found")
            continue
        clone = {k: v for k, v in src.items() if not k.startswith("_")}
        clone["id"] = stable_id
        # Prefer clearer everyday names for aliases.
        if stable_id == "roti_whole_wheat":
            clone["name"] = "Roti / chapati (whole wheat)"
            clone["transliterations"] = ["chapati", "phulka", "roti"]
        elif stable_id == "dal_tadka":
            clone["name"] = "Dal (moong, plain bowl)"
            clone["transliterations"] = ["dal tadka", "dal fry", "moong dal"]
        elif stable_id == "mixed_veg_sabzi":
            clone["name"] = "Mixed veg / matar sabzi"
            clone["transliterations"] = ["sabzi", "matar sabzi"]
        elif stable_id == "egg_bhurji":
            clone["name"] = "Egg bhurji"
            clone["transliterations"] = ["ande ki bhurji", "scrambled egg"]
        aliased.append(clone)
        used_codes.add(code)

    # Drop duplicate INDB rows that were aliased (avoid two entries for same dish).
    final = aliased + [r for r in rows_out if r.get("_indb_code") not in used_codes]
    for r in final:
        r.pop("_indb_code", None)
    return final


def load_ifct_staples(existing_ids: set[str]) -> list[dict]:
    if not IFCT_PATH.exists():
        print(f"warn: missing {IFCT_PATH}; skipping IFCT staples")
        return []

    by_code: dict[str, dict] = {}
    with IFCT_PATH.open(encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            by_code[row["code"]] = row

    out: list[dict] = []
    for code, stable_id, name, trans, unit, amount, grams in IFCT_STAPLES:
        if stable_id in existing_ids:
            continue
        src = by_code.get(code)
        if not src:
            print(f"warn: IFCT {code} missing")
            continue
        kj = num(src.get("enerc")) or 0.0
        protein = num(src.get("protcnt")) or 0.0
        fat = num(src.get("fatce")) or 0.0
        carb = num(src.get("choavldf")) or 0.0
        fiber = num(src.get("fibtg"))
        kcal_per_100 = kj_to_kcal(kj) if kj > 0 else (9.0 * fat if fat > 0 else 0.0)
        scale = grams / 100.0
        out.append(
            food_row(
                seed_id=stable_id,
                name=name,
                transliterations=trans,
                unit=unit,
                amount=amount,
                grams=grams,
                kcal=kcal_per_100 * scale,
                protein=protein * scale,
                carb=carb * scale,
                fat=fat * scale,
                source="IFCT2017",
                confidence="high",
                fibre=(fiber * scale) if fiber is not None else None,
            )
        )
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    foods = load_indb()
    ids = {f["id"] for f in foods}
    foods.extend(load_ifct_staples(ids))

    # Deterministic order: aliases / staples first-ish by name within source.
    foods.sort(key=lambda f: (0 if f["source"] == "IFCT2017" else 1, f["name"].lower(), f["id"]))

    path = OUT / "foods.json"
    path.write_text(json.dumps(foods, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    conf = {}
    src = {}
    for f in foods:
        conf[f["confidence"]] = conf.get(f["confidence"], 0) + 1
        src[f["source"]] = src.get(f["source"], 0) + 1
    print(f"Wrote {len(foods)} foods -> {path}")
    print(f"  by source: {src}")
    print(f"  by confidence: {conf}")


if __name__ == "__main__":
    main()
