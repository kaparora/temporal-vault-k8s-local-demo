#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-temporal-vault-demo}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
VAULT_DB_ROLE="${VAULT_DB_ROLE:-order-worker}"
VAULT_KUBERNETES_ROLE="${VAULT_KUBERNETES_ROLE:-order-worker}"
WORKER_SERVICE_ACCOUNT="${WORKER_SERVICE_ACCOUNT:-order-worker}"

kubectl -n "${NAMESPACE}" exec deployment/vault -- sh -ec "
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN='${VAULT_TOKEN}'

vault auth enable kubernetes 2>/tmp/vault-enable-kubernetes.err || \
  grep -q 'path is already in use' /tmp/vault-enable-kubernetes.err

vault write auth/kubernetes/config \
  token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
  kubernetes_host=\"https://\${KUBERNETES_SERVICE_HOST}:\${KUBERNETES_SERVICE_PORT}\" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

vault policy write order-worker - <<'POLICY'
path \"database/creds/${VAULT_DB_ROLE}\" {
  capabilities = [\"read\"]
}
POLICY

vault write auth/kubernetes/role/${VAULT_KUBERNETES_ROLE} \
  bound_service_account_names='${WORKER_SERVICE_ACCOUNT}' \
  bound_service_account_namespaces='${NAMESPACE}' \
  policies=order-worker \
  ttl=1h

vault read auth/kubernetes/role/${VAULT_KUBERNETES_ROLE}
"
