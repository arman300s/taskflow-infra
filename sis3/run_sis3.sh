#!/usr/bin/env bash
# SIS3: runs all steps from the laptop in order, then the smoke tests.
set -euo pipefail
cd "$(dirname "$0")/.."

for vm in tf-web tf-app tf-db; do
  role=${vm#tf-}
  echo "===== $vm ($role)"
  scp -q sis3/install_packages.sh sis3/setup_firewall.sh "$vm:"
  ssh "$vm" "sudo bash install_packages.sh $role && sudo bash setup_firewall.sh $role"
done

echo "===== smoke tests"
./sis3/smoke_test.sh
