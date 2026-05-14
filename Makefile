SHELL := /bin/bash

CLUSTER_NAME ?= temporal-vault-demo
NAMESPACE ?= temporal-vault-demo
ORDER_ID ?= ORD-001
TEMPORAL_ADDRESS ?= localhost:7233
TEMPORAL_NAMESPACE ?= default
ORDERS_TASK_QUEUE ?= orders-tq
TRANSIT_ORDERS_TASK_QUEUE ?= orders-tq-transit
POSTGRES_HOST ?= localhost
POSTGRES_PORT ?= 5432
POSTGRES_DB ?= temporal
POSTGRES_USER ?= temporal
POSTGRES_PASSWORD ?= temporal
VAULT_ADDR ?= http://localhost:8200
VAULT_TOKEN ?= root
VAULT_TRANSIT_CLIENT_TOKEN ?= demo-transit-client-token
VAULT_DB_MOUNT ?= database
VAULT_DB_ROLE ?= order-validate
VAULT_TRANSIT_MOUNT ?= transit
VAULT_TRANSIT_KEY ?= temporal-payloads
USE_VAULT_DB_CREDS ?= false
USE_VAULT_PAYLOAD_CODEC ?= false
WORKER_IMAGE_NAME ?= temporal-vault-order-worker
WORKER_IMAGE_TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
WORKER_IMAGE ?= $(WORKER_IMAGE_NAME):$(WORKER_IMAGE_TAG)
VAULT_KUBERNETES_ROLE ?= order-worker
WORKER_SERVICE_ACCOUNT ?= order-worker

.PHONY: help setup ports reset-data reset worker-static worker-vault-db demo-build-worker worker-k8s-deploy worker-k8s-transit-deploy worker-transit run-order run-order-transit run-failures verify install up deploy wait db-init vault-deploy vault-init vault-init-transit vault-enable-k8s-auth vault-read-db-creds vault-test-db-creds worker-image worker-load worker-deploy worker-k8s worker-k8s-transit worker-enable-transit worker-disable-transit worker-k8s-restart port-forward port-forward-temporal port-forward-ui port-forward-postgres port-forward-vault worker worker-vault trigger trigger-transit status logs-temporal logs-postgres logs-vault logs-worker db-shell lint test down

help:
	@echo "Demo targets:"
	@echo "  make setup              Install deps, create cluster, deploy services, seed DB/Vault"
	@echo "  make ports              Start all local port-forwards"
	@echo "  make reset-data         Reset demo orders/inventory/payments only"
	@echo "  make reset              Reset demo DB and Vault configuration"
	@echo "  make worker-static      Run local worker with static DB credentials"
	@echo "  make worker-vault-db    Run local worker with Vault dynamic DB credentials"
	@echo "  make demo-build-worker  Build/load the Kubernetes worker image once"
	@echo "  make worker-k8s-deploy  Deploy/switch Kubernetes worker with Vault Kubernetes auth"
	@echo "  make worker-transit     Deploy Kubernetes worker with Vault Transit payload codec"
	@echo "  make run-order          Run ORDER_ID, default ORD-001"
	@echo "  make run-order-transit  Run ORDER_ID through Transit task queue"
	@echo "  make run-failures       Run ORD-001/002/003; ORD-002 and ORD-003 are expected failures"
	@echo "  make verify             Show status, Vault DB smoke test, and worker logs"
	@echo "  make down               Delete the local kind cluster"
	@echo ""
	@echo "Lower-level targets remain available below for development."

setup: install up deploy wait db-init vault-init vault-init-transit vault-enable-k8s-auth

ports: port-forward

reset-data: db-init

reset: db-init vault-init vault-init-transit vault-enable-k8s-auth

worker-static: worker

worker-vault-db:
	TEMPORAL_ADDRESS=$(TEMPORAL_ADDRESS) \
	TEMPORAL_NAMESPACE=$(TEMPORAL_NAMESPACE) \
	ORDERS_TASK_QUEUE=$(ORDERS_TASK_QUEUE) \
	POSTGRES_HOST=$(POSTGRES_HOST) \
	POSTGRES_PORT=$(POSTGRES_PORT) \
	USE_VAULT_DB_CREDS=true \
	VAULT_ADDR=$(VAULT_ADDR) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_DB_MOUNT=$(VAULT_DB_MOUNT) \
	VAULT_DB_ROLE=$(VAULT_DB_ROLE) \
	uv run python -m order_demo.workers.order_worker.main

demo-build-worker: worker-image worker-load

worker-k8s-deploy: worker-deploy worker-disable-transit

worker-k8s-transit-deploy: worker-deploy worker-enable-transit

worker-transit: worker-k8s-transit-deploy

run-order: trigger

run-order-transit: trigger-transit

run-failures:
	$(MAKE) trigger ORDER_ID=ORD-001
	-$(MAKE) trigger ORDER_ID=ORD-002
	-$(MAKE) trigger ORDER_ID=ORD-003

verify: status vault-init vault-test-db-creds logs-worker

# Development targets

install:
	uv sync --all-extras

up:
	kind create cluster --name $(CLUSTER_NAME) --config k8s/kind.yaml

deploy:
	kubectl apply -f k8s/namespace.yaml
	kubectl apply -f k8s/postgres.yaml
	kubectl apply -f k8s/temporal.yaml
	kubectl apply -f k8s/temporal-ui.yaml
	kubectl apply -f k8s/vault.yaml

wait:
	kubectl -n $(NAMESPACE) wait --for=condition=available deployment/postgres --timeout=180s
	kubectl -n $(NAMESPACE) wait --for=condition=available deployment/temporal --timeout=240s
	kubectl -n $(NAMESPACE) wait --for=condition=available deployment/temporal-ui --timeout=180s
	kubectl -n $(NAMESPACE) wait --for=condition=available deployment/vault --timeout=180s

db-init:
	kubectl -n $(NAMESPACE) delete job/db-init --ignore-not-found
	kubectl -n $(NAMESPACE) apply -f k8s/jobs/db-init.yaml
	kubectl -n $(NAMESPACE) wait --for=condition=complete job/db-init --timeout=120s

vault-deploy:
	kubectl apply -f k8s/vault.yaml
	kubectl -n $(NAMESPACE) rollout status deployment/vault --timeout=120s
	kubectl -n $(NAMESPACE) wait --for=condition=available deployment/vault --timeout=120s

vault-init:
	NAMESPACE=$(NAMESPACE) \
	POSTGRES_DB=$(POSTGRES_DB) \
	POSTGRES_USER=$(POSTGRES_USER) \
	POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	bash scripts/vault-init.sh

vault-init-transit:
	NAMESPACE=$(NAMESPACE) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_TRANSIT_CLIENT_TOKEN=$(VAULT_TRANSIT_CLIENT_TOKEN) \
	VAULT_TRANSIT_MOUNT=$(VAULT_TRANSIT_MOUNT) \
	VAULT_TRANSIT_KEY=$(VAULT_TRANSIT_KEY) \
	bash scripts/vault-init-transit.sh

vault-enable-k8s-auth:
	NAMESPACE=$(NAMESPACE) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_TRANSIT_MOUNT=$(VAULT_TRANSIT_MOUNT) \
	VAULT_TRANSIT_KEY=$(VAULT_TRANSIT_KEY) \
	VAULT_KUBERNETES_ROLE=$(VAULT_KUBERNETES_ROLE) \
	WORKER_SERVICE_ACCOUNT=$(WORKER_SERVICE_ACCOUNT) \
	bash scripts/vault-enable-k8s-auth.sh

vault-read-db-creds:
	NAMESPACE=$(NAMESPACE) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_DB_ROLE=$(VAULT_DB_ROLE) \
	bash scripts/vault-read-db-creds.sh

vault-test-db-creds:
	NAMESPACE=$(NAMESPACE) \
	POSTGRES_DB=$(POSTGRES_DB) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_DB_ROLE=$(VAULT_DB_ROLE) \
	bash scripts/vault-test-db-creds.sh

port-forward:
	kubectl -n $(NAMESPACE) port-forward svc/temporal 7233:7233 & \
	kubectl -n $(NAMESPACE) port-forward svc/temporal-ui 8080:8080 & \
	kubectl -n $(NAMESPACE) port-forward svc/postgres 5432:5432 & \
	kubectl -n $(NAMESPACE) port-forward svc/vault 8200:8200 & \
	wait

port-forward-temporal:
	kubectl -n $(NAMESPACE) port-forward svc/temporal 7233:7233

port-forward-ui:
	kubectl -n $(NAMESPACE) port-forward svc/temporal-ui 8080:8080

port-forward-postgres:
	kubectl -n $(NAMESPACE) port-forward svc/postgres 5432:5432

port-forward-vault:
	kubectl -n $(NAMESPACE) port-forward svc/vault 8200:8200

worker:
	TEMPORAL_ADDRESS=$(TEMPORAL_ADDRESS) \
	TEMPORAL_NAMESPACE=$(TEMPORAL_NAMESPACE) \
	ORDERS_TASK_QUEUE=$(ORDERS_TASK_QUEUE) \
	POSTGRES_HOST=$(POSTGRES_HOST) \
	POSTGRES_PORT=$(POSTGRES_PORT) \
	POSTGRES_DB=$(POSTGRES_DB) \
	POSTGRES_USER=$(POSTGRES_USER) \
	POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
	USE_VAULT_DB_CREDS=$(USE_VAULT_DB_CREDS) \
	USE_VAULT_PAYLOAD_CODEC=$(USE_VAULT_PAYLOAD_CODEC) \
	VAULT_ADDR=$(VAULT_ADDR) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_DB_MOUNT=$(VAULT_DB_MOUNT) \
	VAULT_DB_ROLE=$(VAULT_DB_ROLE) \
	VAULT_TRANSIT_MOUNT=$(VAULT_TRANSIT_MOUNT) \
	VAULT_TRANSIT_KEY=$(VAULT_TRANSIT_KEY) \
	uv run python -m order_demo.workers.order_worker.main

worker-vault:
	USE_VAULT_DB_CREDS=true $(MAKE) worker

worker-image:
	docker build -t $(WORKER_IMAGE) .

worker-load:
	kind load docker-image $(WORKER_IMAGE) --name $(CLUSTER_NAME)

worker-deploy:
	sed "s|temporal-vault-order-worker:local|$(WORKER_IMAGE)|g" k8s/order-worker.yaml | kubectl apply -f -
	kubectl -n $(NAMESPACE) rollout status deployment/order-worker --timeout=120s

worker-k8s: worker-image worker-load vault-deploy vault-init vault-enable-k8s-auth worker-deploy

worker-k8s-transit: worker-image worker-load vault-deploy vault-init vault-init-transit vault-enable-k8s-auth worker-deploy worker-enable-transit

worker-enable-transit:
	NAMESPACE=$(NAMESPACE) \
	ORDERS_TASK_QUEUE=$(TRANSIT_ORDERS_TASK_QUEUE) \
	USE_VAULT_PAYLOAD_CODEC=true \
	VAULT_TRANSIT_MOUNT=$(VAULT_TRANSIT_MOUNT) \
	VAULT_TRANSIT_KEY=$(VAULT_TRANSIT_KEY) \
	bash scripts/worker-set-transit.sh

worker-disable-transit:
	NAMESPACE=$(NAMESPACE) \
	ORDERS_TASK_QUEUE=$(ORDERS_TASK_QUEUE) \
	USE_VAULT_PAYLOAD_CODEC=false \
	VAULT_TRANSIT_MOUNT=$(VAULT_TRANSIT_MOUNT) \
	VAULT_TRANSIT_KEY=$(VAULT_TRANSIT_KEY) \
	bash scripts/worker-set-transit.sh

worker-k8s-restart:
	kubectl -n $(NAMESPACE) rollout restart deployment/order-worker
	kubectl -n $(NAMESPACE) rollout status deployment/order-worker --timeout=120s

trigger:
	TEMPORAL_ADDRESS=$(TEMPORAL_ADDRESS) \
	TEMPORAL_NAMESPACE=$(TEMPORAL_NAMESPACE) \
	ORDERS_TASK_QUEUE=$(ORDERS_TASK_QUEUE) \
	USE_VAULT_PAYLOAD_CODEC=false \
	uv run python -m order_demo.client.trigger_order $(ORDER_ID)

trigger-transit:
	TEMPORAL_ADDRESS=$(TEMPORAL_ADDRESS) \
	TEMPORAL_NAMESPACE=$(TEMPORAL_NAMESPACE) \
	ORDERS_TASK_QUEUE=$(TRANSIT_ORDERS_TASK_QUEUE) \
	USE_VAULT_PAYLOAD_CODEC=true \
	VAULT_ADDR=$(VAULT_ADDR) \
	VAULT_TOKEN=$(VAULT_TRANSIT_CLIENT_TOKEN) \
	VAULT_TRANSIT_MOUNT=$(VAULT_TRANSIT_MOUNT) \
	VAULT_TRANSIT_KEY=$(VAULT_TRANSIT_KEY) \
	uv run python -m order_demo.client.trigger_order $(ORDER_ID)

trigger-transit-disabled:
	USE_VAULT_PAYLOAD_CODEC=false $(MAKE) trigger

status:
	kubectl -n $(NAMESPACE) get pods,svc,jobs

logs-temporal:
	kubectl -n $(NAMESPACE) logs deployment/temporal

logs-postgres:
	kubectl -n $(NAMESPACE) logs deployment/postgres

logs-vault:
	kubectl -n $(NAMESPACE) logs deployment/vault

logs-worker:
	kubectl -n $(NAMESPACE) logs deployment/order-worker

db-shell:
	kubectl -n $(NAMESPACE) exec -it deployment/postgres -- psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

lint:
	uv run ruff check .

test:
	uv run pytest

down:
	kind delete cluster --name $(CLUSTER_NAME)
