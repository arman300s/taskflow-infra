#!/usr/bin/env bash
# Deploy a new release to tf-app as automation_bot over SSH (no root, no password).
#   ./deploy.sh
set -euo pipefail
KEY="$HOME/.ssh/taskflow_automation_ed25519"
HOST="automation_bot@$(multipass info tf-app --format csv | tail -1 | cut -d, -f3)"
VERSION=$(grep -oP 'VERSION = "\K[^"]+' app/taskflow_api.py)
SSH=(ssh -i "$KEY" -o BatchMode=yes "$HOST")

"${SSH[@]}" "mkdir -p /opt/taskflow/releases/v$VERSION"
scp -i "$KEY" -q app/taskflow_api.py "$HOST:/opt/taskflow/releases/v$VERSION/"
"${SSH[@]}" "ln -sfn /opt/taskflow/releases/v$VERSION /opt/taskflow/current \
  && sudo systemctl restart taskflow && sleep 1 && curl -s localhost:8000/health"
echo; echo "deployed v$VERSION"
