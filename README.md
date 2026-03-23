# Azure FinOps Cost Audit Toolkit

Azure-first FinOps repository inspired by the AWS workflow in [hari8g/Jannis_awscostexplorer](https://github.com/hari8g/Jannis_awscostexplorer.git).

This repository now includes **Phase 1 + Phase 2**:
- Setup and validation commands
- Live audit and export-CSV audit runners
- Service-focused findings for core Azure domains
- Severity and savings heuristics
- Baseline comparison (`new` / `fixed` / `regressed` placeholder)
- Text + JSON report generation in `./reports`

## Quick Start

```bash
# 1) Validate prerequisites
./setup.sh

# 2) Validate scripts
./build.sh

# 3) Live audit (all supported service categories)
./live-audit.sh --subscription "<subscription-id>" --all

# 4) Export CSV audit
./export-audit.sh --csv /path/to/azure-cost-export.csv
```

## Phase 2 Highlights

- Added service categories:
  - `virtual-machines`
  - `aks`
  - `sql`
  - `storage`
  - `network`
- Added findings engines:
  - `scripts/generate_live_findings.py`
  - `scripts/generate_export_findings.py`
- Added baseline diff support in both runners:
  - `--baseline <previous-report.json>`
- Added savings ranges (monthly + annual) and severity scoring
- Added service module docs under `services/`

## Repository Structure

```text
.
├── README.md
├── .gitignore
├── setup.sh
├── build.sh
├── live-audit.sh
├── export-audit.sh
├── scripts/
│   ├── summarize_azure_export.py
│   ├── generate_live_findings.py
│   └── generate_export_findings.py
├── shared/
│   └── lib/
│       └── common.sh
├── services/
│   ├── virtual-machines/README.md
│   ├── aks/README.md
│   ├── sql/README.md
│   ├── storage/README.md
│   └── network/README.md
├── docs/
│   └── AZURE_MIGRATION_PLAN.md
└── reports/
```

## Prerequisites

- `bash` 4+
- `az` (Azure CLI)
- `jq`
- `python3`

## Commands

### Setup

```bash
./setup.sh
```

Checks local dependencies, verifies `./reports`, and checks Azure CLI login state.

### Build / Validation

```bash
./build.sh
```

Runs:
- `bash -n` on shell scripts
- `py_compile` for Python helper scripts

### Live Audit

```bash
./live-audit.sh --subscription "<subscription-id>" [--all] [--services "virtual-machines,aks,sql,storage,network"] [--top 200] [--baseline ./reports/prev-live.json]
```

What it does:
- Sets Azure subscription context
- Pulls subscription metadata
- Pulls usage data (`az consumption usage list`)
- Pulls advisor cost recommendations (`az advisor recommendation list --category Cost`)
- Generates findings with:
  - severity (`low|medium|high`)
  - savings estimates (`savings_low`, `savings_high`)
  - annualized savings in summary
- Optionally computes baseline diff

### Export CSV Audit

```bash
./export-audit.sh --csv /path/to/azure-cost-export.csv [--services "virtual-machines,aks,sql,storage,network"] [--baseline ./reports/prev-export.json]
```

What it does:
- Parses Azure Cost Management export CSV
- Computes rollups by:
  - resource group
  - service
  - subscription
- Generates findings with severity and savings estimates
- Optionally computes baseline diff

## Service Selection

Both runners support:

```text
--services "virtual-machines,aks,sql,storage,network"
```

Short aliases accepted by heuristics:
- `vm` -> `virtual-machines`
- `aks`
- `sql`
- `storage`
- `network`

## Baseline Diff

If `--baseline` is provided and file exists, output JSON includes:

```json
"baseline_diff": {
  "baseline_file": "...",
  "new": ["..."],
  "fixed": ["..."],
  "regressed": []
}
```

Current implementation compares finding IDs to detect `new` and `fixed`.  
`regressed` is reserved for deeper logic in a later phase.

## Output

Each audit writes to `./reports/`:
- `*.txt`: human-readable summary
- `*.json`: full structured result

Typical JSON fields include:
- `summary.finding_count`
- `summary.savings_low` / `summary.savings_high`
- `summary.savings_annual_low` / `summary.savings_annual_high`
- `findings[]` with `id`, `service`, `severity`, `message`, `evidence`

## Phase Status

- Phase 1: complete
- Phase 2: complete
- Phase 3 (next): multi-subscription runner, dashboard, CI policy gates

## Source Inspiration

- [hari8g/Jannis_awscostexplorer](https://github.com/hari8g/Jannis_awscostexplorer.git)
