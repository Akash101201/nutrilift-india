# Nutrition source data

Place cleared-for-use downloads here (gitignored under `raw/`):

| File | Source |
|------|--------|
| `raw/INDB.xlsx` | [Indian Nutrient Databank](https://github.com/lindsayjaacks/Indian-Nutrient-Databank-INDB-) |
| `raw/ifct-compositions.csv` | IFCT 2017 compositions export (e.g. from the `ifct2017` package) |

Regenerate the app catalog:

```bash
python scripts/build_foods_catalog.py
# or
python scripts/generate_seeds.py
```

Citations:

- Longvah, T., Ananthan, R., Bhaskarachary, K. and Venkaiah, K. (2017). Indian Food Composition Tables 2017, NIN/ICMR.
- Indian Nutrient Databank (INDB) — Jaacks Lab / Anuvaad (recipe nutrient databank).
