#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T2: After Vault worker"
note "Stop 03_T2_worker_static_db.sh with Ctrl-C before running this script."
note "This local worker asks Vault for dynamic Postgres credentials."
note "Expected log signal: db_credential_source=vault and v-token-order-..."

step "Refresh Vault database secrets"
run make vault-init

run make worker-vault-db
