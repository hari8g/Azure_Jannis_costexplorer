#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/lib/common.sh"

log_info "Checking prerequisites..."

missing=0
for cmd in bash az jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Missing: $cmd"
    missing=1
  else
    log_info "Found: $cmd"
  fi
done

if [[ "$missing" -ne 0 ]]; then
  cat >&2 <<'EOF'
One or more prerequisites are missing.
Install required tools, then re-run ./setup.sh
EOF
  exit 1
fi

ensure_reports_dir
log_info "Created/verified ./reports directory"

log_info "Checking Azure CLI login state..."
if az account show >/dev/null 2>&1; then
  sub_name="$(az account show --query name -o tsv 2>/dev/null || true)"
  log_info "Azure login detected. Current subscription: ${sub_name:-unknown}"
else
  log_warn "Azure CLI not logged in. Run: az login"
fi

cat <<'EOF'
Setup complete.
Next steps:
  1) az login
  2) ./live-audit.sh --subscription "<subscription-id>" --all
  3) ./export-audit.sh --csv /path/to/azure-cost-export.csv
EOF
