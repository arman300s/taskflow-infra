#!/usr/bin/env bash
# Free Ampere A1 capacity is often exhausted ("Out of host capacity").
# Try every availability domain, and repeat until all servers are created.
# Servers that were created stay (lifecycle ignore_changes on availability_domain).
#   ./apply_retry.sh [max_rounds]
set -uo pipefail
cd "$(dirname "$0")"
ROUNDS=${1:-30}
LOG=$(mktemp)
for round in $(seq 1 "$ROUNDS"); do
  for ad in 1 2 3; do
    echo "== round $round, availability domain $ad"
    if tofu apply -auto-approve -input=false -no-color -var "ad_number=$ad" > "$LOG" 2>&1; then
      sed -n '/^Outputs:/,$p' "$LOG"
      exit 0
    fi
    grep -E 'Creation complete.*instance|^Error' "$LOG" | sed 's/\[id=.*//' | sort | uniq -c
  done
  sleep 60
done
echo "no capacity after $ROUNDS rounds"; exit 1
