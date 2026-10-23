# TaskFlow infrastructure

Scripts for the *Linux for DevOps and Cloud* SIS assignments.
TaskFlow is a small task manager running on 3 Ubuntu 24.04 servers:
`tf-web` (Nginx), `tf-app` (Python API), `tf-db` (PostgreSQL).
SIS1/SIS2 were first done on local Multipass VMs; the project now runs on
Oracle Cloud (Always Free, Frankfurt) – see `oracle/`.

## SIS1 – machines and filesystem
| File | Purpose |
|---|---|
| `cloud-init.yaml` | base configuration of every VM on first boot |
| `create_vms.sh` | creates the 3 VMs |
| `setup_fs.sh <web\|app\|db>` | directory layout, service user, sample files |

## SIS2 – users, permissions, SSH, systemd
| File | Purpose |
|---|---|
| `setup_users.sh` | role groups, users, ACL file permissions, sudoers (run on each VM) |
| `setup_ssh.sh` | SSH key pair for `automation_bot`, sshd hardening (run on host) |
| `app/taskflow_api.py` | TaskFlow API service (Python stdlib) |
| `app/taskflow.service` | systemd unit |
| `install_service.sh` | installs and enables the unit on `tf-app` |
| `deploy.sh` | deploys a new release as `automation_bot` over SSH |
| `run_sis2.sh` | runs all SIS2 steps in order |

## Oracle Cloud – SIS1/SIS2 on real servers (`oracle/`)
| File | Purpose |
|---|---|
| `oracle/provision_base.sh <role>` | same as `cloud-init.yaml` + `/etc/hosts` + UFW (keeps Oracle's InstanceServices rules) |
| `oracle/install_roles.sh <role>` | Nginx / Python / PostgreSQL (private listen address, DB + user, daily backup) |
| `oracle/run_sis1.sh` | SIS1 on all servers from the laptop (replaces `create_vms.sh`) |
| `oracle/run_sis2.sh`, `oracle/setup_ssh.sh`, `oracle/deploy.sh` | SIS2 over SSH instead of `multipass exec` |

Needs SSH aliases `tf-web`, `tf-app`, `tf-db` in `~/.ssh/config`. Secrets are generated
into `oracle/.env` (git-ignored).

## SIS3 – packages, network, firewall, smoke tests (`sis3/`)
| File | Purpose |
|---|---|
| `sis3/install_packages.sh <role>` | apt (jq, fail2ban), new repo apt.postgresql.org (psql 18), GitHub binary (node_exporter, checksum verified) |
| `sis3/setup_firewall.sh <role>` | UFW per role, rate-limited SSH, metrics only from 10.0.0.0/16, fail2ban |
| `sis3/smoke_test.sh` | 37 checks: SSH, packages, services, firewall, allowed and blocked network paths |
| `sis3/run_sis3.sh` | all SIS3 steps + smoke tests |
| `sis3/logs/` | output of the runs |

| Server | Public IP | Private IP | Open ports |
|---|---|---|---|
| tf-web | 92.5.56.128 | 10.0.0.21 | 22 (limit), 80; 9100 private |
| tf-app | 92.5.88.31 | 10.0.0.209 | 22 (limit); 8000, 9100 private |
| tf-db | 130.61.232.1 | 10.0.0.165 | 22 (limit); 5432, 9100 private |

## Usage
```bash
sudo snap install multipass
./create_vms.sh                     # SIS1 (Multipass)
./run_sis2.sh                       # SIS2 (Multipass)
./oracle/run_sis1.sh                # SIS1 on Oracle Cloud
./oracle/run_sis2.sh                # SIS2 on Oracle Cloud
./sis3/run_sis3.sh                  # SIS3 + smoke tests
./oracle/deploy.sh                  # release a new version
```

## Roles
| Role (group) | User | Superuser rights |
|---|---|---|
| tf-admins | tfadmin | `ALL` (with password) |
| tf-developers | tfdev | start/stop/restart taskflow, `nginx -t`, reload nginx, read service logs |
| tf-auditors | tfauditor | NOPASSWD read-only: `ufw status`, `lastb`, `ss -tulpn`, service logs |
| tf-automation | automation_bot | NOPASSWD: restart taskflow, reload nginx, daemon-reload; SSH key only |
| service | taskflow, www-data, postgres | none, `nologin` shell |
