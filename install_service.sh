#!/usr/bin/env bash
# SIS2: install TaskFlow API as a systemd unit. Run on tf-app as root:
#   sudo ./install_service.sh /path/to/app
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

SRC="${1:-./app}"
VERSION=$(grep -oP 'VERSION = "\K[^"]+' "$SRC/taskflow_api.py")
RELEASE=/opt/taskflow/releases/v$VERSION

# stop the old manual (nohup) test process from SIS1, if any
pkill -f /opt/taskflow/app.py && echo "old nohup process stopped" || true

install -d "$RELEASE"
install -m 755 "$SRC/taskflow_api.py" "$RELEASE/"
ln -sfn "$RELEASE" /opt/taskflow/current
chown -R taskflow:taskflow /opt/taskflow/releases
chown -h taskflow:taskflow /opt/taskflow/current

install -m 644 "$SRC/taskflow.service" /etc/systemd/system/taskflow.service
systemctl daemon-reload
systemctl enable --now taskflow
systemctl --no-pager status taskflow | head -5
