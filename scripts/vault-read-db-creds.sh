#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-temporal-vault-demo}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_DB_ROLE="${VAULT_DB_ROLE:-order-worker}"

kubectl -n "${NAMESPACE}" exec deployment/vault -- sh -ec "
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN='${VAULT_TOKEN}'
vault read database/creds/${VAULT_DB_ROLE}
"
