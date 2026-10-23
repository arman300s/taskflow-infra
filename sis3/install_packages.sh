#!/usr/bin/env bash
# SIS3: install packages in three different ways. Run on every server as root:
#   sudo ./install_packages.sh <web|app|db>
#   1. default Ubuntu repository (apt):   jq, fail2ban                   - all servers
#   2. new apt repository (PostgreSQL):   postgresql-client-18           - tf-app
#   3. without apt (GitHub binary):       Prometheus node_exporter       - all servers
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

ROLE="${1:?usage: $0 <web|app|db>}"
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_SUSPEND=1   # no "restarting services" prompts/noise

echo "[1] default repository: jq, fail2ban"
apt-get update -qq
apt-get install -y -qq jq fail2ban >/dev/null
apt-cache policy jq | sed -n 1,3p
echo "  jq $(jq --version), fail2ban $(fail2ban-client --version | sed -n 1p)"

echo "[2] new repository: PostgreSQL Global Development Group (apt.postgresql.org)"
if [[ $ROLE == app ]]; then
  apt-get install -y -qq ca-certificates curl gnupg >/dev/null
  install -d /usr/share/postgresql-common/pgdg
  # repository signing key, stored separately and bound to this repo only (signed-by)
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
  . /etc/os-release
  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] \
https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list
  apt-get update -qq
  apt-get install -y -qq postgresql-client-18 >/dev/null
  apt-cache policy postgresql-client-18 | sed -n 1,3p
  echo "  $(/usr/lib/postgresql/18/bin/psql --version)"
else
  echo "  skipped (only tf-app needs the newer client)"
fi

echo "[3] without apt: node_exporter from GitHub releases"
NE_VERSION=1.12.1
case "$(uname -m)" in
  aarch64) NE_ARCH=arm64 ;;
  x86_64)  NE_ARCH=amd64 ;;
  *) echo "unsupported arch"; exit 1 ;;
esac
NE_NAME="node_exporter-${NE_VERSION}.linux-${NE_ARCH}"
NE_URL="https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}"
if [[ "$(/usr/local/bin/node_exporter --version 2>&1 | sed -n 1p)" != *"version ${NE_VERSION}"* ]]; then
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/$NE_NAME.tar.gz" "$NE_URL/$NE_NAME.tar.gz"
  curl -fsSL -o "$tmp/sha256sums.txt"  "$NE_URL/sha256sums.txt"
  # verify the download against the published checksum before installing
  (cd "$tmp" && grep " $NE_NAME.tar.gz\$" sha256sums.txt | sha256sum -c -)
  tar -xzf "$tmp/$NE_NAME.tar.gz" -C "$tmp"
  install -m 755 "$tmp/$NE_NAME/node_exporter" /usr/local/bin/node_exporter
  rm -rf "$tmp"
fi
id node_exporter &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter
PRIVATE_IP=$(hostname -I | awk '{print $1}')
cat > /etc/systemd/system/node_exporter.service <<UNIT
[Unit]
Description=Prometheus node_exporter (system metrics)
Documentation=https://github.com/prometheus/node_exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
# listen only on the private network address, never on the public one
ExecStart=/usr/local/bin/node_exporter --web.listen-address=${PRIVATE_IP}:9100
Restart=on-failure
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now node_exporter >/dev/null 2>&1
systemctl restart node_exporter
echo "  $(/usr/local/bin/node_exporter --version 2>&1 | sed -n 1p)"
echo "  listening on ${PRIVATE_IP}:9100, service $(systemctl is-active node_exporter)"

echo "Done: packages installed on $(hostname)"
