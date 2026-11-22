# TaskFlow - one command to build, test or destroy the whole project.
#   make up       servers (OpenTofu) + full setup and smoke tests (Ansible)
#   make test     smoke tests only
#   make down     destroy all servers and the network
#   make rebuild  down + up  (the demo: from nothing to a working project)
#   make image    build and publish the container image to Docker Hub

# tools installed in ~/.local/opt/bin (OpenTofu binary, Ansible virtualenv)
export PATH := $(HOME)/.local/opt/bin:$(PATH)

DOCKERHUB_USER ?= armanj8543foiun
IMAGE          := $(DOCKERHUB_USER)/taskflow-status
IMAGE_TAG      ?= 1.0.0

.PHONY: up infra config test down rebuild image plan

up: infra config

plan:
	cd tofu && tofu init -input=false >/dev/null && tofu plan

infra:
	cd tofu && tofu init -input=false >/dev/null && ./apply_retry.sh
	@rm -f ~/.ssh/known_hosts_taskflow   # new servers have new SSH host keys

config:
	cd ansible && ansible-playbook site.yml

test:
	cd ansible && ansible-playbook smoke.yml

down:
	cd tofu && tofu destroy -auto-approve

rebuild: down up

image:
	@# multi-platform builds need a BuildKit builder in a container (not the default 'docker' driver)
	docker buildx inspect taskflow-builder >/dev/null 2>&1 || \
	  docker buildx create --name taskflow-builder --driver docker-container
	docker buildx build --builder taskflow-builder --platform linux/arm64,linux/amd64 \
	  -t $(IMAGE):$(IMAGE_TAG) -t $(IMAGE):latest --push status-app
