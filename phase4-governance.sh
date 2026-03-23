#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared/lib/common.sh"

REPORT=""
HISTORY_DIR="$SCRIPT_DIR/reports/history"
REQUIRED_TAGS="owner,costCenter,environment"
RESOURCE_SNAPSHOT=""
OUT_PREFIX=""

usage() {
  cat <<'EOF'
Usage:
  ./phase4-governance.sh --report <report.json> [--history-dir DIR] [--required-tags LIST] [--resource-snapshot FILE] [--out-prefix PREFIX]

Options:
  --report FILE            Input audit report JSON (required)
  --history-dir DIR        Historical reports directory for anomaly detection
  --required-tags LIST     Required tags list (default: owner,costCenter,environment)
  --resource-snapshot FILE JSON snapshot from `az resource list -o json`
  --out-prefix PREFIX      Output prefix path (default: ./reports/phase4-<timestamp>)
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report) REPORT="${2:-}"; shift 2 ;;
    --history-dir) HISTORY_DIR="${2:-$HISTORY_DIR}"; shift 2 ;;
    --required-tags) REQUIRED_TAGS="${2:-$REQUIRED_TAGS}"; shift 2 ;;
    --resource-snapshot) RESOURCE_SNAPSHOT="${2:-}"; shift 2 ;;
    --out-prefix) OUT_PREFIX="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) log_error "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$REPORT" || ! -f "$REPORT" ]]; then
  log_error "Valid --report is required"
  exit 1
fi

require_cmd python3
ensure_reports_dir

if [[ -z "$OUT_PREFIX" ]]; then
  OUT_PREFIX="$(report_file_base "phase4-governance")"
fi

anomaly_json="${OUT_PREFIX}-anomaly.json"
tag_json="${OUT_PREFIX}-tag-compliance.json"
alert_json="${OUT_PREFIX}-alert-payload.json"
txt_out="${OUT_PREFIX}.txt"

mkdir -p "$HISTORY_DIR"
python3 "$SCRIPT_DIR/scripts/detect_anomalies.py" \
  --current-report "$REPORT" \
  --history-dir "$HISTORY_DIR" \
  --out "$anomaly_json" >/dev/null

if [[ -z "$RESOURCE_SNAPSHOT" ]]; then
  log_info "No --resource-snapshot provided, collecting resources with Azure CLI..."
  require_cmd az
  RESOURCE_SNAPSHOT="$(mktemp)"
  az resource list -o json > "$RESOURCE_SNAPSHOT"
fi

python3 "$SCRIPT_DIR/scripts/check_tag_compliance.py" \
  --resources-json "$RESOURCE_SNAPSHOT" \
  --required-tags "$REQUIRED_TAGS" \
  --out "$tag_json" >/dev/null

python3 "$SCRIPT_DIR/scripts/build_alert_payload.py" \
  --report "$REPORT" \
  --anomaly "$anomaly_json" \
  --tag-compliance "$tag_json" \
  --out "$alert_json" >/dev/null

{
  echo "Phase 4 Governance Summary"
  echo "Input report: $REPORT"
  echo "Anomaly check: $(jq -r '.anomaly_detected' "$anomaly_json") (z=$(jq -r '.z_score' "$anomaly_json"))"
  echo "Tag compliance: $(jq -r '.summary.compliance_percentage' "$tag_json")%"
  echo "Alert status: $(jq -r '.status' "$alert_json")"
  echo "Alert reasons: $(jq -r '.reasons | join(",")' "$alert_json")"
  echo
  echo "Anomaly JSON: $anomaly_json"
  echo "Tag compliance JSON: $tag_json"
  echo "Alert payload JSON: $alert_json"
} > "$txt_out"

if [[ -n "${RESOURCE_SNAPSHOT:-}" && "$RESOURCE_SNAPSHOT" == /var/*/tmp* ]]; then
  rm -f "$RESOURCE_SNAPSHOT"
fi

log_info "Summary: $txt_out"
echo "Done."
