#!/usr/bin/env bash
set -euo pipefail

PAYLOAD=""
WEBHOOK_URL=""

usage() {
  cat <<'EOF'
Usage:
  ./alerts/notify.sh --payload <alert-payload.json> [--webhook-url URL]

If --webhook-url is omitted, prints payload to stdout.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --payload) PAYLOAD="${2:-}"; shift 2 ;;
    --webhook-url) WEBHOOK_URL="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$PAYLOAD" || ! -f "$PAYLOAD" ]]; then
  echo "Valid --payload is required" >&2
  exit 1
fi

if [[ -z "$WEBHOOK_URL" ]]; then
  jq . "$PAYLOAD"
  exit 0
fi

curl -sS -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  --data-binary "@$PAYLOAD"

echo "Notification sent."
