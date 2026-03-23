#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/lib/common.sh"

log_info "Validating shell scripts..."
for file in \
  "$SCRIPT_DIR/setup.sh" \
  "$SCRIPT_DIR/live-audit.sh" \
  "$SCRIPT_DIR/export-audit.sh" \
  "$SCRIPT_DIR/shared/lib/common.sh"
do
  bash -n "$file"
  log_info "bash -n passed: $file"
done

log_info "Validating Python script syntax..."
python3 -m py_compile "$SCRIPT_DIR/scripts/summarize_azure_export.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/generate_live_findings.py"
python3 -m py_compile "$SCRIPT_DIR/scripts/generate_export_findings.py"
log_info "py_compile passed"

echo "Build/validation complete."
