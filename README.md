# Azure FinOps Cost Audit Toolkit

Azure-first FinOps repository inspired by the AWS workflow in [hari8g/Jannis_awscostexplorer](https://github.com/hari8g/Jannis_awscostexplorer.git).

This repository now includes **Phase 1 + Phase 2**:
- Setup and validation commands
- Live audit and export-CSV audit runners
- Service-focused findings for core Azure domains
- Severity and savings heuristics
- Baseline comparison (`new` / `fixed` / `regressed` placeholder)
- Text + JSON report generation in `./reports`
- Multi-subscription aggregation runner
- HTML dashboard generation
- CI policy gates
- Phase 4 governance checks (anomaly, tag compliance, alert payload)

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

# 5) Multi-subscription live audit
./multi-subscription-audit.sh --subscriptions "sub1,sub2,sub3"

# 6) Dashboard generation
./dashboard/dashboard-gen.sh --reports ./reports --out ./reports/dashboard.html

# 7) Phase 4 governance checks
./phase4-governance.sh --report ./reports/<latest-report>.json
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
├── multi-subscription-audit.sh
├── phase4-governance.sh
├── scripts/
│   ├── summarize_azure_export.py
│   ├── generate_live_findings.py
│   ├── generate_export_findings.py
│   ├── policy_gate.py
│   ├── detect_anomalies.py
│   ├── check_tag_compliance.py
│   └── build_alert_payload.py
├── alerts/
│   └── notify.sh
├── dashboard/
│   ├── dashboard-gen.py
│   └── dashboard-gen.sh
├── .github/workflows/
│   └── ci-policy-gates.yml
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

### Multi-Subscription Audit

```bash
./multi-subscription-audit.sh --subscriptions "sub1,sub2,sub3" [--services "virtual-machines,aks,sql,storage,network"] [--top 200] [--baseline-dir ./baselines]
```

What it does:
- Runs `live-audit.sh` across each subscription ID
- Aggregates findings and savings into a single summary JSON/TXT
- Supports per-subscription baseline file lookup in `--baseline-dir`

### Dashboard

```bash
./dashboard/dashboard-gen.sh --reports ./reports --out ./reports/dashboard.html --title "Azure FinOps Dashboard"
```

What it does:
- Scans report JSON files in `--reports`
- Builds a single HTML dashboard with:
  - total reports
  - total findings
  - aggregate savings low/high
  - per-report summary table

### CI Policy Gates

Workflow file:
- `.github/workflows/ci-policy-gates.yml`

Gate script:
- `scripts/policy_gate.py`

Policy gate example:

```bash
python3 scripts/policy_gate.py \
  --report ./reports/azure-live-cost-audit-<timestamp>.json \
  --max-high-severity 0 \
  --max-findings 50
```

### Phase 4 Governance (Milestone 1)

```bash
./phase4-governance.sh \
  --report ./reports/azure-live-cost-audit-<timestamp>.json \
  --history-dir ./reports/history \
  --required-tags owner,costCenter,environment
```

What it does:
- Detects anomalies in `summary.savings_high` against historical report trend (`z-score`)
- Checks required tag compliance on Azure resources
- Builds a unified alert payload JSON

Output artifacts:
- `*-anomaly.json`
- `*-tag-compliance.json`
- `*-alert-payload.json`
- `*.txt` summary

Optional notification:

```bash
./alerts/notify.sh --payload ./reports/<phase4-alert-payload>.json
./alerts/notify.sh --payload ./reports/<phase4-alert-payload>.json --webhook-url "https://example.com/webhook"
```

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
- Phase 3: complete
- Phase 4: in progress (Milestone 1 implemented)

## Source Inspiration

- [hari8g/Jannis_awscostexplorer](https://github.com/hari8g/Jannis_awscostexplorer.git)
