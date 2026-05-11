#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-temporal-vault-demo}"
USE_VAULT_PAYLOAD_CODEC="${USE_VAULT_PAYLOAD_CODEC:-true}"
VAULT_TRANSIT_MOUNT="${VAULT_TRANSIT_MOUNT:-transit}"
VAULT_TRANSIT_KEY="${VAULT_TRANSIT_KEY:-temporal-payloads}"
ORDERS_TASK_QUEUE="${ORDERS_TASK_QUEUE:-orders-tq-transit}"

kubectl -n "${NAMESPACE}" set env deployment/order-worker \
  ORDERS_TASK_QUEUE="${ORDERS_TASK_QUEUE}" \
  USE_VAULT_PAYLOAD_CODEC="${USE_VAULT_PAYLOAD_CODEC}" \
  VAULT_TRANSIT_MOUNT="${VAULT_TRANSIT_MOUNT}" \
  VAULT_TRANSIT_KEY="${VAULT_TRANSIT_KEY}"

kubectl -n "${NAMESPACE}" rollout status deployment/order-worker --timeout=120s
