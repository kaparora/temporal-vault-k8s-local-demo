#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-temporal-vault-demo}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_TRANSIT_MOUNT="${VAULT_TRANSIT_MOUNT:-transit}"
VAULT_TRANSIT_KEY="${VAULT_TRANSIT_KEY:-temporal-payloads}"

kubectl -n "${NAMESPACE}" exec deployment/vault -- sh -ec "
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN='${VAULT_TOKEN}'

vault secrets enable -path='${VAULT_TRANSIT_MOUNT}' transit 2>/tmp/vault-enable-transit.err || \
  grep -q 'path is already in use' /tmp/vault-enable-transit.err

vault write -f '${VAULT_TRANSIT_MOUNT}/keys/${VAULT_TRANSIT_KEY}'
vault read '${VAULT_TRANSIT_MOUNT}/keys/${VAULT_TRANSIT_KEY}'
"
