#!/usr/bin/env bash
# SIS3: smoke tests for the whole TaskFlow system. Run from the laptop:
#   ./sis3/smoke_test.sh
# Needs the SSH aliases tf-web, tf-app, tf-db in ~/.ssh/config.
set -uo pipefail

WEB_IP=92.5.56.128; APP_IP=92.5.88.31; DB_IP=130.61.232.1
PASS=0; FAIL=0
if [[ -t 1 ]]; then G=$'\e[32m'; R=$'\e[31m'; B=$'\e[1m'; N=$'\e[0m'; else G=; R=; B=; N=; fi

check() { # check "<description>" "<shell command that must succeed>"
  if out=$(bash -c "$2" 2>&1); then
    printf "  ${G}PASS${N}  %-52s %s\n" "$1" "$(head -1 <<<"$out" | tr -s " \t" " " | cut -c1-42)"; ((PASS++))
  else
    printf "  ${R}FAIL${N}  %-52s %s\n" "$1" "$(tail -1 <<<"$out" | tr -s " \t" " " | cut -c1-42)"; ((FAIL++))
  fi
}
closed() { ! nc -z -G 3 "$1" "$2" 2>/dev/null; }   # port must NOT answer from the internet
export -f closed

echo "${B}== 1. Servers reachable over SSH${N}"
for h in tf-web tf-app tf-db; do
  check "$h: SSH login" "ssh -o ConnectTimeout=8 $h hostname | grep -x $h"
done

echo "${B}== 2. Packages (default repo / new repo / binary)${N}"
for h in tf-web tf-app tf-db; do
  check "$h: jq (apt, default repo)"          "ssh $h jq --version"
  check "$h: fail2ban running (apt)"          "ssh $h systemctl is-active fail2ban"
  check "$h: node_exporter running (binary)"  "ssh $h 'systemctl is-active node_exporter && node_exporter --version 2>&1 | head -1 | cut -d\" \" -f1-3'"
done
check "tf-app: PGDG repository configured"     "ssh tf-app 'apt-cache policy postgresql-client-18 | grep -m1 apt.postgresql.org'"
check "tf-app: psql 18 client (new repo)"      "ssh tf-app /usr/lib/postgresql/18/bin/psql --version"

echo "${B}== 3. Services${N}"
check "tf-web: nginx active"                   "ssh tf-web systemctl is-active nginx"
check "tf-web: nginx config valid"             "ssh tf-web sudo nginx -t 2>&1 | grep successful"
check "tf-app: taskflow API active + enabled"  "ssh tf-app 'systemctl is-active taskflow && systemctl is-enabled taskflow'"
check "tf-db: postgresql active"               "ssh tf-db systemctl is-active postgresql"

echo "${B}== 4. Firewall${N}"
for h in tf-web tf-app tf-db; do
  check "$h: UFW active, SSH rate-limited"     "s=\$(ssh $h sudo ufw status) && grep -q 'Status: active' <<<\"\$s\" && grep -m1 'OpenSSH .*LIMIT' <<<\"\$s\""
  check "$h: fail2ban sshd jail on"            "ssh $h sudo fail2ban-client status sshd | grep -m1 'Currently banned'"
done

echo "${B}== 5. Network: allowed paths${N}"
check "internet -> tf-web:80  web page"        "curl -fsS -m 5 http://$WEB_IP/ | grep -o '<h1>TaskFlow</h1>'"
check "internet -> tf-web -> tf-app  /api/health" "curl -fsS -m 5 http://$WEB_IP/api/health | grep '\"ok\"'"
check "internet -> POST /api/tasks (201)"      "curl -s -o /dev/null -w '%{http_code}' -m 5 -X POST -d '{\"title\":\"smoke test $(date +%T)\"}' http://$WEB_IP/api/tasks | grep -x 201"
check "tf-web -> tf-app:8000 (private)"        "ssh tf-web curl -fsS -m 5 http://tf-app:8000/health"
check "tf-app -> tf-db:5432 SQL query"         "ssh tf-app 'set -a; . <(sudo cat /etc/taskflow/app.env); /usr/lib/postgresql/18/bin/psql \"\$DB_URL\" -tAc \"select count(*) from tasks\"'"
for h in tf-web tf-app tf-db; do
  check "tf-web -> $h:9100 metrics (private)"  "ssh tf-web curl -fsS -m 5 http://$h:9100/metrics | grep -m1 '^node_uname_info'"
done

echo "${B}== 6. Network: blocked from the internet${N}"
check "internet -> tf-app:8000 blocked"        "closed $APP_IP 8000"
check "internet -> tf-db:5432 blocked"         "closed $DB_IP 5432"
for ip in $WEB_IP $APP_IP $DB_IP; do
  check "internet -> $ip:9100 blocked"         "closed $ip 9100"
done

echo
echo "${B}Result: ${G}$PASS passed${N}${B}, ${R}$FAIL failed${N}"
[[ $FAIL -eq 0 ]]
