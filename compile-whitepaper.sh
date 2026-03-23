#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$SCRIPT_DIR/docs"
OUT_DIR="$SCRIPT_DIR/reports/whitepapers"

declare -a TARGETS=()
declare -a FORMATS=()

usage() {
  cat <<'EOF'
Usage:
  ./compile-whitepaper.sh [virtual-machines|aks|sql|storage|network] [--format pdf|docx] [--all]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    virtual-machines|aks|sql|storage|network) TARGETS+=("$1"); shift ;;
    --format) FORMATS+=("${2:-pdf}"); shift 2 ;;
    --all) TARGETS=(virtual-machines aks sql storage network); shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

[[ "${#TARGETS[@]}" -gt 0 ]] || TARGETS=(virtual-machines aks sql storage network)
[[ "${#FORMATS[@]}" -gt 0 ]] || FORMATS=(pdf)

command -v pandoc >/dev/null 2>&1 || { echo "pandoc required: brew install pandoc" >&2; exit 1; }
mkdir -p "$OUT_DIR"

for svc in "${TARGETS[@]}"; do
  src="$DOCS_DIR/whitepaper-${svc}.md"
  if [[ ! -f "$src" ]]; then
    cat > "$src" <<EOF
# Azure ${svc} Cost Engineering Whitepaper

This whitepaper is generated from the Azure FinOps toolkit.

## Scope
- Service: ${svc}
- Focus: Optimization opportunities, governance, and operational controls
EOF
  fi
  for fmt in "${FORMATS[@]}"; do
    out="$OUT_DIR/${svc}-cost-engineering-whitepaper.${fmt}"
    case "$fmt" in
      pdf|docx) pandoc "$src" -o "$out" ;;
      *) echo "Unsupported format: $fmt" >&2; exit 1 ;;
    esac
    echo "Generated: $out"
  done
done
