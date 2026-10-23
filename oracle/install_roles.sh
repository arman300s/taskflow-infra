#!/usr/bin/env bash
# SIS1 on Oracle Cloud: key software of each role. Run as root after setup_fs.sh:
#   sudo DB_PASS=... ./install_roles.sh <web|app|db>
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

ROLE="${1:?usage: $0 <web|app|db>}"
export DEBIAN_FRONTEND=noninteractive

case "$ROLE" in
web)
  apt-get install -y -qq nginx >/dev/null
  # use the site config created by setup_fs.sh
  ln -sfn /etc/taskflow/nginx/taskflow.conf /etc/nginx/sites-enabled/taskflow
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
  nginx -v
  ;;
app)
  apt-get install -y -qq python3 python3-venv python3-pip >/dev/null
  python3 --version
  ;;
db)
  : "${DB_PASS:?set DB_PASS}"
  apt-get install -y -qq postgresql >/dev/null
  CONF=$(ls -d /etc/postgresql/*/main)
  # listen on the private network, accept only tf-app's subnet with a password
  sed -i "s/^#\?listen_addresses.*/listen_addresses = 'localhost,10.0.0.165'/" "$CONF/postgresql.conf"
  grep -q 'taskflow' "$CONF/pg_hba.conf" || \
    echo "host  taskflow  taskflow  10.0.0.0/16  scram-sha-256" >> "$CONF/pg_hba.conf"
  systemctl restart postgresql
  sudo -u postgres psql -qtc "SELECT 1 FROM pg_roles WHERE rolname='taskflow'" | grep -q 1 || \
    sudo -u postgres psql -qc "CREATE ROLE taskflow LOGIN PASSWORD '$DB_PASS'"
  sudo -u postgres psql -qtc "SELECT 1 FROM pg_database WHERE datname='taskflow'" | grep -q 1 || \
    sudo -u postgres createdb -O taskflow taskflow
  sudo -u postgres psql -q -d taskflow -f /etc/taskflow/db/init.sql
  sudo -u postgres psql -q -d taskflow -c "ALTER TABLE users OWNER TO taskflow; ALTER TABLE tasks OWNER TO taskflow;"
  # daily backup at 02:00 (script created by setup_fs.sh)
  echo "0 2 * * * root /usr/local/bin/taskflow-backup.sh" > /etc/cron.d/taskflow-backup
  psql --version
  ;;
*) echo "unknown role: $ROLE"; exit 1 ;;
esac
echo "Done: $ROLE software installed on $(hostname)"
