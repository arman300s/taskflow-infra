#!/usr/bin/env bash
# SIS2: runs all steps from the host in order.
set -euo pipefail
cd "$(dirname "$0")"

for vm in tf-web tf-app tf-db; do
  echo "===== roles on $vm"
  multipass transfer setup_users.sh "$vm:/home/ubuntu/setup_users.sh"
  multipass exec "$vm" -- sudo bash /home/ubuntu/setup_users.sh
done

echo "===== SSH"
./setup_ssh.sh

echo "===== systemd service on tf-app"
multipass exec tf-app -- mkdir -p /home/ubuntu/app
multipass transfer app/taskflow_api.py app/taskflow.service tf-app:/home/ubuntu/app/
multipass transfer install_service.sh tf-app:/home/ubuntu/install_service.sh
multipass exec tf-app -- sudo bash /home/ubuntu/install_service.sh /home/ubuntu/app
