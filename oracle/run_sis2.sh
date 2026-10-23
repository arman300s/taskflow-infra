#!/usr/bin/env bash
# SIS2 on Oracle Cloud: runs all steps from the laptop in order.
set -euo pipefail
cd "$(dirname "$0")/.."

for vm in tf-web tf-app tf-db; do
  echo "===== roles on $vm"
  scp -q setup_users.sh "$vm:setup_users.sh"
  ssh "$vm" sudo bash setup_users.sh
done

echo "===== SSH"
./oracle/setup_ssh.sh

echo "===== systemd service on tf-app"
# first install v1.0.0 by hand, deploy.sh later rolls out the current version
ssh tf-app mkdir -p app
scp -q app/taskflow_api.py app/taskflow.service tf-app:app/
ssh tf-app "sed -i 's/^VERSION = .*/VERSION = \"1.0.0\"/' app/taskflow_api.py"
scp -q install_service.sh tf-app:install_service.sh
ssh tf-app sudo bash install_service.sh /home/ubuntu/app
