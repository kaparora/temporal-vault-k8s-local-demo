#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-temporal-vault-demo}"
POSTGRES_DB="${POSTGRES_DB:-temporal}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_DB_ROLE="${VAULT_DB_ROLE:-order-worker}"

vault_exec() {
  kubectl -n "${NAMESPACE}" exec deployment/vault -- sh -ec "
    export VAULT_ADDR=http://127.0.0.1:8200
    export VAULT_TOKEN='${VAULT_TOKEN}'
    vault read -field=$1 database/creds/${VAULT_DB_ROLE}
  "
}

username="$(vault_exec username)"
password="$(vault_exec password)"

echo "Testing dynamic Vault credential: ${username}"

kubectl -n "${NAMESPACE}" exec deployment/postgres -- env PGPASSWORD="${password}" \
  psql -U "${username}" -d "${POSTGRES_DB}" \
  -c "SELECT id, status FROM orders ORDER BY id;"
