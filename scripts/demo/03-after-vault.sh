#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "After Vault: dynamic database credentials"
note "Stop the static worker if it is still running."
note "Start make worker-vault in another terminal before running this script."
note "Expected worker log signal: db_credential_source=vault and v-token-order-..."

step "Reset demo data"
run make db-init

step "Refresh Vault database secrets"
run make vault-init

step "Show a generated database credential"
note "This uses the narrow order-validate helper role."
run make vault-read-db-creds

step "Trigger the happy-path order"
run make trigger ORDER_ID=ORD-001

step "What to show"
note "Worker logs should show Vault-generated Postgres usernames."
note "This removes static DB credentials from the worker runtime path."
