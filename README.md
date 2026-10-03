# TaskFlow infrastructure

Scripts for the *Linux for DevOps and Cloud* SIS assignments.
TaskFlow is a small task manager running on 3 Ubuntu 24.04 VMs (Multipass / KVM):
`tf-web` (Nginx), `tf-app` (Python API), `tf-db` (PostgreSQL).

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

## Usage
```bash
sudo snap install multipass
./create_vms.sh                     # SIS1
./run_sis2.sh                       # SIS2
./deploy.sh                         # release a new version
```

## Roles
| Role (group) | User | Superuser rights |
|---|---|---|
| tf-admins | tfadmin | `ALL` (with password) |
| tf-developers | tfdev | start/stop/restart taskflow, `nginx -t`, reload nginx, read service logs |
| tf-auditors | tfauditor | NOPASSWD read-only: `ufw status`, `lastb`, `ss -tulpn`, service logs |
| tf-automation | automation_bot | NOPASSWD: restart taskflow, reload nginx, daemon-reload; SSH key only |
| service | taskflow, www-data, postgres | none, `nologin` shell |
