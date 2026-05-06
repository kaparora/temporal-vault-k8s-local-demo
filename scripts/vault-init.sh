#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-temporal-vault-demo}"
POSTGRES_DB="${POSTGRES_DB:-temporal}"
POSTGRES_USER="${POSTGRES_USER:-temporal}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-temporal}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_DB_ROLE="${VAULT_DB_ROLE:-order-worker}"

kubectl -n "${NAMESPACE}" exec deployment/vault -- sh -ec "
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN='${VAULT_TOKEN}'

vault secrets enable database 2>/tmp/vault-enable-database.err || \
  grep -q 'path is already in use' /tmp/vault-enable-database.err

vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles='${VAULT_DB_ROLE}' \
  connection_url='postgresql://{{username}}:{{password}}@postgres:5432/${POSTGRES_DB}?sslmode=disable' \
  username='${POSTGRES_USER}' \
  password='${POSTGRES_PASSWORD}'

vault write database/roles/${VAULT_DB_ROLE} \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";'

vault read database/roles/${VAULT_DB_ROLE}
"
