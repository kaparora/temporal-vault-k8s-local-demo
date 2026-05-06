SHELL := /bin/bash

CLUSTER_NAME ?= temporal-vault-demo
NAMESPACE ?= temporal-vault-demo
ORDER_ID ?= ORD-001
TEMPORAL_ADDRESS ?= localhost:7233
TEMPORAL_NAMESPACE ?= default
ORDERS_TASK_QUEUE ?= orders-tq
POSTGRES_HOST ?= localhost
POSTGRES_PORT ?= 5432
POSTGRES_DB ?= temporal
POSTGRES_USER ?= temporal
POSTGRES_PASSWORD ?= temporal
VAULT_ADDR ?= http://localhost:8200
VAULT_TOKEN ?= root
VAULT_DB_MOUNT ?= database
VAULT_DB_ROLE ?= order-worker
USE_VAULT_DB_CREDS ?= false

.PHONY: install up deploy wait db-init vault-init vault-read-db-creds vault-test-db-creds port-forward port-forward-temporal port-forward-ui port-forward-postgres port-forward-vault worker worker-vault trigger status logs-temporal logs-postgres logs-vault db-shell lint test down

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

vault-init:
	NAMESPACE=$(NAMESPACE) \
	POSTGRES_DB=$(POSTGRES_DB) \
	POSTGRES_USER=$(POSTGRES_USER) \
	POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_DB_ROLE=$(VAULT_DB_ROLE) \
	bash scripts/vault-init.sh

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
	VAULT_ADDR=$(VAULT_ADDR) \
	VAULT_TOKEN=$(VAULT_TOKEN) \
	VAULT_DB_MOUNT=$(VAULT_DB_MOUNT) \
	VAULT_DB_ROLE=$(VAULT_DB_ROLE) \
	uv run python -m order_demo.workers.order_worker.main

worker-vault:
	USE_VAULT_DB_CREDS=true $(MAKE) worker

trigger:
	TEMPORAL_ADDRESS=$(TEMPORAL_ADDRESS) \
	TEMPORAL_NAMESPACE=$(TEMPORAL_NAMESPACE) \
	ORDERS_TASK_QUEUE=$(ORDERS_TASK_QUEUE) \
	uv run python -m order_demo.client.trigger_order $(ORDER_ID)

status:
	kubectl -n $(NAMESPACE) get pods,svc,jobs

logs-temporal:
	kubectl -n $(NAMESPACE) logs deployment/temporal

logs-postgres:
	kubectl -n $(NAMESPACE) logs deployment/postgres

logs-vault:
	kubectl -n $(NAMESPACE) logs deployment/vault

db-shell:
	kubectl -n $(NAMESPACE) exec -it deployment/postgres -- psql -U $(POSTGRES_USER) -d $(POSTGRES_DB)

lint:
	uv run ruff check .

test:
	uv run pytest

down:
	kind delete cluster --name $(CLUSTER_NAME)
