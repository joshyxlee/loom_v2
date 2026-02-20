# Question Bank Audit & Report Generator

## Run
```bash
python3 tools/qbank_audit.py
```

## Inputs
- `assets/questions/*.json`

## Outputs
- `reports/questions_full.html`
- `reports/red_flags.html`
- `reports/summary.json`

## Notes
- Uses Python stdlib only.
- Fails with a clear error if any JSON file is invalid.
- Forbidden phrases and generic coaching tone list are editable in `tools/qbank_audit.py`.
