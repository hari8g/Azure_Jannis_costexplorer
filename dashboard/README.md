# Dashboard

Azure FinOps dashboard generator.

## Usage

```bash
./dashboard/dashboard-gen.sh --reports ./reports --out ./reports/dashboard.html
```

## Inputs

- JSON report files created by `live-audit.sh`, `export-audit.sh`, and multi-subscription summaries.

## Output

- `dashboard.html` with summary cards and per-report table.
