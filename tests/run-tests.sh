#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[tests] build validation"
"$ROOT_DIR/build.sh" >/dev/null

echo "[tests] action plan/executive summary smoke"
mkdir -p "$ROOT_DIR/tmp"
cat > "$ROOT_DIR/tmp/test-report.json" <<'EOF'
{
  "summary": { "finding_count": 2, "savings_low": 20, "savings_high": 80 },
  "findings": [
    { "id": "f1", "service": "virtual-machines", "severity": "high", "effort": "quick-win", "message": "m1", "savings_low": 10, "savings_high": 50 },
    { "id": "f2", "service": "storage", "severity": "low", "effort": "medium", "message": "m2", "savings_low": 10, "savings_high": 30 }
  ]
}
EOF
"$ROOT_DIR/action-plan.sh" "$ROOT_DIR/tmp/test-report.json" --top 1 >/dev/null
"$ROOT_DIR/executive-summary.sh" "$ROOT_DIR/tmp/test-report.json" --output md >/dev/null

echo "[tests] dashboard smoke"
"$ROOT_DIR/dashboard/dashboard-gen.sh" --reports "$ROOT_DIR/reports" --out "$ROOT_DIR/reports/dashboard.html" >/dev/null || true

echo "[tests] passed"
