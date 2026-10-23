#!/usr/bin/env bash
# SIS3: firewall rules for SSH and the TaskFlow network services. Run as root:
#   sudo ./setup_firewall.sh <web|app|db>
# Layer 1 (cloud):  Oracle VCN Security List - set in the OCI console, see README.
# Layer 2 (server): UFW (nftables backend) - this script.
# Layer 3 (server): fail2ban bans IPs that keep failing SSH logins - this script.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

ROLE="${1:?usage: $0 <web|app|db>}"
NET=10.0.0.0/16          # TaskFlow private network (Oracle VCN)

echo "[1] default policies"
ufw default deny incoming  >/dev/null
ufw default allow outgoing >/dev/null
ufw default deny routed    >/dev/null
ufw logging low            >/dev/null

echo "[2] SSH: open to the world (admins, class demo) but rate-limited"
# 'limit' denies an IP that opens 6+ connections within 30 seconds
ufw delete allow OpenSSH >/dev/null 2>&1 || true
ufw limit OpenSSH comment 'SSH, rate-limited' >/dev/null

echo "[3] service ports of this role"
case "$ROLE" in
  web) ufw allow 80/tcp comment 'HTTP - Nginx, public' >/dev/null ;;
  app) ufw allow from "$NET" to any port 8000 proto tcp comment 'TaskFlow API - from tf-web' >/dev/null ;;
  db)  ufw allow from "$NET" to any port 5432 proto tcp comment 'PostgreSQL - from tf-app' >/dev/null ;;
  *)   echo "unknown role: $ROLE"; exit 1 ;;
esac
# metrics of every server can be read only from inside the private network
ufw allow from "$NET" to any port 9100 proto tcp comment 'node_exporter metrics - private' >/dev/null
ufw --force enable >/dev/null
ufw status verbose

echo "[4] fail2ban: ban SSH brute force for 1 hour"
cat > /etc/fail2ban/jail.local <<JAIL
[DEFAULT]
# never ban the servers' own private network
ignoreip = 127.0.0.1/8 ::1 $NET
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
JAIL
systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban
sleep 2
fail2ban-client status sshd

echo "Done: firewall configured on $(hostname) ($ROLE)"
