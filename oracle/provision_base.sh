#!/usr/bin/env bash
# SIS1 on Oracle Cloud: the same base setup as cloud-init.yaml, plus the per-role
# firewall. Run on every server as root:  sudo ./provision_base.sh <web|app|db>
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

ROLE="${1:?usage: $0 <web|app|db>}"
NET=10.0.0.0/16          # Oracle VCN private network

echo "[1] timezone, packages"
timedatectl set-timezone Asia/Almaty
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq >/dev/null
apt-get install -y -qq vim curl git htop tree net-tools ufw acl >/dev/null

echo "[2] private names of the TaskFlow servers"
sed -i '/# taskflow$/d' /etc/hosts
cat >> /etc/hosts <<'HOSTS'
10.0.0.21   tf-web  # taskflow
10.0.0.209  tf-app  # taskflow
10.0.0.165  tf-db   # taskflow
HOSTS

echo "[3] firewall (UFW)"
# Oracle images ship iptables-persistent with rules that reject everything except
# SSH; installing ufw removes that package, so UFW manages the firewall from now on.
# Oracle's InstanceServices rules (only root may reach the iSCSI boot volume and
# metadata endpoints on 169.254.x.x) are moved into UFW so they survive reboots.
if [[ -f /etc/iptables/rules.v4 ]] && ! grep -q 'oracle instance services' /etc/ufw/before.rules; then
  { echo "# oracle instance services (from /etc/iptables/rules.v4)"
    sed -n 's/^-A InstanceServices /-A ufw-before-output /p' /etc/iptables/rules.v4
  } > /tmp/oracle.rules
  sed -i "/^# don't delete the 'COMMIT' line/e cat /tmp/oracle.rules" /etc/ufw/before.rules
  rm /tmp/oracle.rules
fi
# remove the old Oracle rules still loaded in the kernel from boot time
if iptables -L InstanceServices -n &>/dev/null; then
  iptables -F INPUT; iptables -F FORWARD
  iptables -D OUTPUT -d 169.254.0.0/16 -j InstanceServices
  iptables -F InstanceServices; iptables -X InstanceServices
fi

ufw allow OpenSSH >/dev/null
case "$ROLE" in
  web) ufw allow 80/tcp >/dev/null ;;
  app) ufw allow from "$NET" to any port 8000 proto tcp >/dev/null ;;
  db)  ufw allow from "$NET" to any port 5432 proto tcp >/dev/null ;;
  *)   echo "unknown role: $ROLE"; exit 1 ;;
esac
ufw --force enable >/dev/null
ufw status verbose

echo "TaskFlow node ($ROLE) provisioned on $(date)" > /etc/motd
echo "Done: base provisioning for $(hostname) ($ROLE)"
