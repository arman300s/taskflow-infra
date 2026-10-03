#!/usr/bin/env bash
# SIS2: SSH key pair for automation_bot + sshd hardening on every VM. Run on the HOST.
set -euo pipefail

KEY="$HOME/.ssh/taskflow_automation_ed25519"
VMS=(tf-web tf-app tf-db)

# 1. key pair (private key never leaves the host, never goes to git)
[[ -f $KEY ]] || ssh-keygen -t ed25519 -N "" -C "automation_bot@taskflow" -f "$KEY"
PUB=$(cat "$KEY.pub")

for vm in "${VMS[@]}"; do
  echo ">> $vm"
  multipass exec "$vm" -- sudo bash -s <<REMOTE
set -e
# 2. install public key for automation_bot
install -d -m 700 -o automation_bot -g tf-automation /home/automation_bot/.ssh
echo "$PUB" > /home/automation_bot/.ssh/authorized_keys
chown automation_bot:tf-automation /home/automation_bot/.ssh/authorized_keys
chmod 600 /home/automation_bot/.ssh/authorized_keys

# 3. harden sshd (50- is read before cloud 60- file, first value wins)
cat > /etc/ssh/sshd_config.d/50-taskflow.conf <<'CONF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
LoginGraceTime 30
AllowGroups ubuntu tf-admins tf-developers tf-auditors tf-automation
CONF
sshd -t && systemctl reload ssh
echo "   key installed, sshd reloaded"
REMOTE
done

# 4. test: key-based login as the automation user
for vm in "${VMS[@]}"; do
  ip=$(multipass info "$vm" --format csv | tail -1 | cut -d, -f3)
  ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
      "automation_bot@$ip" 'echo "   OK: $(whoami)@$(hostname) via SSH key"'
done
