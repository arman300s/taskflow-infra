#!/usr/bin/env bash
# Creates the 3 TaskFlow virtual machines with Multipass (Ubuntu 24.04 LTS)
set -euo pipefail

IMAGE="24.04"
CLOUD_INIT="$(dirname "$0")/cloud-init.yaml"

#        name    cpus  memory  disk
VMS=(
  "tf-web  1     1G      8G"
  "tf-app  1     1G      8G"
  "tf-db   1     2G      10G"
)

for vm in "${VMS[@]}"; do
  read -r name cpus mem disk <<< "$vm"
  if multipass info "$name" &>/dev/null; then
    echo ">> $name already exists, skipping"
    continue
  fi
  echo ">> Launching $name ($cpus CPU, $mem RAM, $disk disk)"
  multipass launch "$IMAGE" --name "$name" --cpus "$cpus" --memory "$mem" \
    --disk "$disk" --cloud-init "$CLOUD_INIT" --timeout 900
done

multipass list
