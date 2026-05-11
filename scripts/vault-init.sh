#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-temporal-vault-demo}"
POSTGRES_DB="${POSTGRES_DB:-temporal}"
POSTGRES_USER="${POSTGRES_USER:-temporal}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-temporal}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_DB_ROLES="${VAULT_DB_ROLES:-order-validate,order-reserve-inventory,order-release-inventory,order-process-payment,order-fulfill,order-fail,order-send-notification}"

kubectl -n "${NAMESPACE}" exec deployment/vault -- sh -ec "
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN='${VAULT_TOKEN}'

vault secrets enable database 2>/tmp/vault-enable-database.err || \
  grep -q 'path is already in use' /tmp/vault-enable-database.err

vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles='${VAULT_DB_ROLES}' \
  connection_url='postgresql://{{username}}:{{password}}@postgres:5432/${POSTGRES_DB}?sslmode=disable' \
  username='${POSTGRES_USER}' \
  password='${POSTGRES_PASSWORD}'

vault write database/roles/order-validate \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT ON orders, order_items TO \"{{name}}\";'

vault write database/roles/order-reserve-inventory \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT ON orders, inventory_reservations TO \"{{name}}\"; GRANT SELECT, UPDATE ON inventory TO \"{{name}}\"; GRANT INSERT ON inventory_reservations TO \"{{name}}\";'

vault write database/roles/order-release-inventory \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, DELETE ON inventory_reservations TO \"{{name}}\"; GRANT SELECT, UPDATE ON inventory TO \"{{name}}\";'

vault write database/roles/order-process-payment \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, INSERT, UPDATE ON payments TO \"{{name}}\";'

vault write database/roles/order-fulfill \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, UPDATE ON orders TO \"{{name}}\"; GRANT SELECT, INSERT ON fulfilments TO \"{{name}}\";'

vault write database/roles/order-fail \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, UPDATE ON orders TO \"{{name}}\";'

vault write database/roles/order-send-notification \
  db_name=postgres \
  default_ttl=15m \
  max_ttl=1h \
  creation_statements='CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '\''{{password}}'\'' VALID UNTIL '\''{{expiration}}'\''; GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, INSERT ON notifications TO \"{{name}}\";'

vault delete database/roles/order-status 2>/tmp/vault-delete-order-status.err || true
vault delete database/roles/order-worker 2>/tmp/vault-delete-order-worker.err || true

vault list database/roles
"
