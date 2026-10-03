#!/usr/bin/env bash
# SIS2: TaskFlow roles - groups, users, file permissions (ACL) and sudoers.
# Run on every VM:  sudo ./setup_users.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }

TEMP_PASS="${TEMP_PASS:-ChangeMe_2026}"   # first-login password, must be changed

echo "[1] packages"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq acl >/dev/null

echo "[2] groups"
for g in tf-admins tf-developers tf-auditors tf-automation; do
  getent group "$g" >/dev/null || { groupadd "$g"; echo "  group $g created"; }
done

echo "[3] service accounts"
# app service account (created in SIS1 by setup_fs.sh, ensure it exists)
id taskflow &>/dev/null || useradd --system --home-dir /opt/taskflow --shell /usr/sbin/nologin taskflow
for u in taskflow www-data postgres; do
  id "$u" &>/dev/null && echo "  $(id "$u")  shell=$(getent passwd "$u" | cut -d: -f7)"
done

echo "[4] human users and bot"
add_user() { # add_user <name> <primary role group> <extra groups> <comment>
  local name=$1 group=$2 extra=$3 comment=$4
  if ! id "$name" &>/dev/null; then
    useradd -m -s /bin/bash -c "$comment" -g "$group" ${extra:+-G "$extra"} "$name"
    echo "  user $name created"
  fi
  chmod 750 "/home/$name"
}
add_user tfadmin        tf-admins     ""                    "TaskFlow administrator"
add_user tfdev          tf-developers ""                    "TaskFlow developer"
add_user tfauditor      tf-auditors   "adm,systemd-journal" "TaskFlow auditor"
add_user automation_bot tf-automation ""                    "TaskFlow CI/CD bot"

# humans: temporary password, forced change on first login
for u in tfadmin tfdev tfauditor; do
  echo "$u:$TEMP_PASS" | chpasswd
  chage -d 0 "$u"
done
# bot: no password at all, SSH key only ('*' = no valid password, but not locked)
usermod -p '*' automation_bot

echo "[5] file permissions (ACL)"
acl() { # acl <path> <entries...>   - applies access + default ACL if path exists
  local path=$1; shift
  [[ -e $path ]] || return 0
  for e in "$@"; do
    setfacl -R -m "$e" "$path"
    [[ -d $path ]] && setfacl -R -d -m "$e" "$path"
  done
  echo "  $path -> $*"
}
acl /opt/taskflow        g:tf-developers:rwx g:tf-automation:rwx g:tf-auditors:r-x
acl /var/www/taskflow    g:tf-developers:rwx g:tf-automation:rwx g:tf-auditors:r-x
acl /var/log/taskflow    g:tf-developers:r-x g:tf-auditors:r-x
[[ -d /etc/taskflow ]] && setfacl -m g:tf-developers:r-x,g:tf-auditors:r-x /etc/taskflow \
  && echo "  /etc/taskflow -> developers/auditors r-x (secrets in app.env stay 640)"
# /srv/taskflow (user data) and /var/backups/taskflow: NO group access, admins via sudo only

echo "[6] sudoers"
cat > /etc/sudoers.d/taskflow <<'SUDO'
# TaskFlow role-based sudo rules (managed by setup_users.sh)
Cmnd_Alias TF_SERVICE = /usr/bin/systemctl start taskflow, /usr/bin/systemctl stop taskflow, \
                        /usr/bin/systemctl restart taskflow, /usr/bin/systemctl --no-pager status taskflow
Cmnd_Alias TF_NGINX   = /usr/sbin/nginx -t, /usr/bin/systemctl reload nginx
Cmnd_Alias TF_LOGS    = /usr/bin/journalctl --no-pager -u taskflow, /usr/bin/journalctl --no-pager -u nginx, \
                        /usr/bin/journalctl --no-pager -u postgresql
Cmnd_Alias TF_AUDIT   = /usr/sbin/ufw status verbose, /usr/bin/lastb, /usr/bin/ss -tulpn, \
                        /usr/bin/cat /etc/sudoers.d/taskflow

%tf-admins     ALL=(ALL:ALL) ALL
%tf-developers ALL=(root) TF_SERVICE, TF_NGINX, TF_LOGS
%tf-auditors   ALL=(root) NOPASSWD: TF_AUDIT, TF_LOGS
%tf-automation ALL=(root) NOPASSWD: TF_SERVICE, TF_NGINX, /usr/bin/systemctl daemon-reload
SUDO
chmod 440 /etc/sudoers.d/taskflow
visudo -cf /etc/sudoers.d/taskflow

echo "Done: roles configured on $(hostname)"
