#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/lib/common.sh"

log_info "Validating shell scripts..."
for file in \
  "$SCRIPT_DIR/setup.sh" \
  "$SCRIPT_DIR/live-audit.sh" \
  "$SCRIPT_DIR/cur-audit.sh" \
  "$SCRIPT_DIR/export-audit.sh" \
  "$SCRIPT_DIR/action-plan.sh" \
  "$SCRIPT_DIR/executive-summary.sh" \
  "$SCRIPT_DIR/ci-entrypoint.sh" \
  "$SCRIPT_DIR/compile-whitepaper.sh" \
  "$SCRIPT_DIR/multi-account-audit.sh" \
  "$SCRIPT_DIR/multi-subscription-audit.sh" \
  "$SCRIPT_DIR/phase4-governance.sh" \
  "$SCRIPT_DIR/alerts/notify.sh" \
  "$SCRIPT_DIR/dashboard/dashboard-gen.sh" \
  "$SCRIPT_DIR/tests/run-tests.sh" \
  "$SCRIPT_DIR/shared/lib/common.sh"
do
  bash -n "$file"
  log_info "bash -n passed: $file"
done

log_info "Validating Python script syntax..."
python3 -m py_compile "$SCRIPT_DIR/scripts/summarize_azure_export.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/generate_live_findings.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/generate_export_findings.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/policy_gate.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/detect_anomalies.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/check_tag_compliance.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/build_alert_payload.py"
python3 -m py_compile "$SCRIPT_DIR/dashboard/dashboard-gen.py"
log_info "py_compile passed"

echo "Build/validation complete."
