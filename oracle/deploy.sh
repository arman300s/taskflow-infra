#!/usr/bin/env bash
# Deploy a new release to tf-app as automation_bot over SSH (no root, no password).
#   ./oracle/deploy.sh          (from the repository root)
set -euo pipefail
cd "$(dirname "$0")/.."
KEY="$HOME/.ssh/taskflow_automation_ed25519"
HOST="automation_bot@tf-app"
VERSION=$(sed -n 's/^VERSION = "\(.*\)"/\1/p' app/taskflow_api.py)
OPTS=(-i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes)

ssh "${OPTS[@]}" "$HOST" "mkdir -p /opt/taskflow/releases/v$VERSION"
scp "${OPTS[@]}" -q app/taskflow_api.py "$HOST:/opt/taskflow/releases/v$VERSION/"
ssh "${OPTS[@]}" "$HOST" "ln -sfn /opt/taskflow/releases/v$VERSION /opt/taskflow/current \
  && sudo systemctl restart taskflow && sleep 1 && curl -s localhost:8000/health"
echo; echo "deployed v$VERSION"
