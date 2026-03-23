#!/usr/bin/env bash
set -euo pipefail

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

today_utc() {
  date -u +"%Y-%m-%d"
}

ensure_reports_dir() {
  mkdir -p "./reports"
}

report_file_base() {
  local prefix="${1:-azure-cost-audit}"
  local ts
  ts="$(date -u +"%Y%m%d-%H%M%S")"
  echo "./reports/${prefix}-${ts}"
}

log_info() {
  printf "[INFO] %s\n" "$*" >&2
}

log_warn() {
  printf "[WARN] %s\n" "$*" >&2
}

log_error() {
  printf "[ERROR] %s\n" "$*" >&2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Missing required command: $cmd"
    return 1
  fi
}

apply_baseline_diff() {
  local current_json="$1"
  local baseline_json="$2"

  if [[ ! -f "$baseline_json" ]]; then
    log_warn "Baseline file not found, skipping diff: $baseline_json"
    return 0
  fi

  local tmp_file
  tmp_file="$(mktemp)"

  jq -n \
    --slurpfile curr "$current_json" \
    --slurpfile base "$baseline_json" \
    --arg baseline_path "$baseline_json" \
    '
    def ids(x): (x.findings // [] | map(.id));
    ($base[0]) as $b
    | ($curr[0]) as $c
    | (ids($b)) as $base_ids
    | (ids($c)) as $curr_ids
    | ($c + {
        baseline_diff: {
          baseline_file: $baseline_path,
          new: ($curr_ids - $base_ids),
          fixed: ($base_ids - $curr_ids),
          regressed: []
        }
      })
    ' > "$tmp_file"

  mv "$tmp_file" "$current_json"
}
