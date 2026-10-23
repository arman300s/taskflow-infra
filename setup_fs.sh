#!/usr/bin/env bash
# TaskFlow filesystem layout: creates directories, service user and sample files.
# Usage: sudo ./setup_fs.sh <web|app|db|all>
set -euo pipefail

ROLE="${1:-all}"
APP=taskflow
APP_USER=taskflow

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo $0 $ROLE"; exit 1
fi

# --- service user (no login shell, owns app files) ---
if ! id "$APP_USER" &>/dev/null; then
  useradd --system --home-dir /opt/$APP --shell /usr/sbin/nologin "$APP_USER"
  echo "created system user $APP_USER"
fi

mk() { # mk <dir> <owner> <mode>
  install -d -o "$2" -g "$2" -m "$3" "$1"
  echo "  dir  $1  ($2, $3)"
}
file() { # file <path> <owner> <mode>  (content from stdin)
  cat > "$1"; chown "$2:$2" "$1"; chmod "$3" "$1"
  echo "  file $1"
}

common() {
  echo "[common]"
  mk /etc/$APP              root      755   # configuration
  mk /var/log/$APP          $APP_USER 750   # logs
  mk /var/backups/$APP      root      700   # backups
  file /etc/$APP/$APP.conf root 644 <<CONF
# TaskFlow common configuration
ENV=production
ROLE=$ROLE
LOG_DIR=/var/log/$APP
WEB_HOST=tf-web
APP_HOST=tf-app
DB_HOST=tf-db
CONF
  file /var/log/$APP/$APP.log $APP_USER 640 <<< "$(date -Is) INFO filesystem initialised for role=$ROLE"
}

web() {
  echo "[web]"
  mk /var/www/$APP                 www-data 755   # static front-end
  mk /var/www/$APP/assets          www-data 755
  mk /etc/$APP/nginx               root     755
  file /var/www/$APP/index.html www-data 644 <<'HTML'
<!doctype html>
<html><head><title>TaskFlow</title></head>
<body><h1>TaskFlow</h1><p>Simple task manager - front-end placeholder.</p></body></html>
HTML
  file /etc/$APP/nginx/taskflow.conf root 644 <<'NGX'
server {
    listen 80;
    server_name _;
    root /var/www/taskflow;
    index index.html;
    location /api/ { proxy_pass http://tf-app:8000/; }
}
NGX
}

app() {
  echo "[app]"
  mk /opt/$APP                     $APP_USER 755   # application code
  mk /opt/$APP/releases            $APP_USER 755   # versioned releases
  mk /srv/$APP                     $APP_USER 750   # user data
  mk /srv/$APP/uploads             $APP_USER 750   # files uploaded by users
  mk /var/lib/$APP                 $APP_USER 750   # app runtime data / cache
  # sample secrets only on the first run - never overwrite real ones
  if [[ ! -f /etc/$APP/app.env ]]; then
    file /etc/$APP/app.env root 640 <<'ENV'
# Backend secrets (sample values!)
APP_PORT=8000
DB_URL=postgresql://taskflow:CHANGE_ME@tf-db:5432/taskflow
SECRET_KEY=CHANGE_ME
ENV
    chgrp $APP_USER /etc/$APP/app.env
  else
    echo "  keep /etc/$APP/app.env (already exists)"
  fi
  file /opt/$APP/app.py $APP_USER 644 <<'PY'
# TaskFlow API placeholder
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b'{"status":"ok"}')
HTTPServer(("0.0.0.0", 8000), H).serve_forever()
PY
  file /srv/$APP/uploads/README.txt $APP_USER 640 <<< "User uploaded files are stored here."
}

db() {
  echo "[db]"
  mk /etc/$APP/db                  root 755
  mk /var/backups/$APP/db          root 700   # pg_dump output
  file /etc/$APP/db/init.sql root 644 <<'SQL'
-- TaskFlow initial schema (sample)
CREATE TABLE IF NOT EXISTS users (
    id         SERIAL PRIMARY KEY,
    email      TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS tasks (
    id         SERIAL PRIMARY KEY,
    user_id    INT REFERENCES users(id),
    title      TEXT NOT NULL,
    done       BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);
SQL
  file /usr/local/bin/$APP-backup.sh root 755 <<'BK'
#!/usr/bin/env bash
# Daily DB backup (to be scheduled with cron)
sudo -u postgres pg_dump taskflow > /var/backups/taskflow/db/taskflow_$(date +%F).sql
BK
}

common
case "$ROLE" in
  web) web ;;
  app) app ;;
  db)  db  ;;
  all) web; app; db ;;
  *) echo "unknown role: $ROLE (use web|app|db|all)"; exit 1 ;;
esac
echo "Done: filesystem for role '$ROLE' is ready."
