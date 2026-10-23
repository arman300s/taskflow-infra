#!/usr/bin/env bash
# SIS1 on Oracle Cloud: run from the laptop. Needs the SSH aliases tf-web, tf-app
# and tf-db in ~/.ssh/config (the replacement for create_vms.sh + multipass exec).
set -euo pipefail
cd "$(dirname "$0")/.."

# DB password: generated once, kept only on the laptop (.env is in .gitignore)
[[ -f oracle/.env ]] || printf "DB_PASS=%s\nSECRET_KEY=%s\n" \
  "$(openssl rand -hex 16)" "$(openssl rand -hex 32)" > oracle/.env
source oracle/.env

for vm in tf-web tf-app tf-db; do
  role=${vm#tf-}
  echo "===== $vm ($role)"
  scp -q setup_fs.sh oracle/provision_base.sh oracle/install_roles.sh "$vm:"
  ssh "$vm" "sudo bash provision_base.sh $role \
          && sudo bash setup_fs.sh $role \
          && sudo DB_PASS=$DB_PASS bash install_roles.sh $role"
done

# real secrets in the app secrets file (setup_fs.sh writes a CHANGE_ME sample)
ssh tf-app "sudo sed -i -e 's|taskflow:CHANGE_ME@|taskflow:$DB_PASS@|' \\
  -e 's|^SECRET_KEY=CHANGE_ME|SECRET_KEY=$SECRET_KEY|' /etc/taskflow/app.env"
