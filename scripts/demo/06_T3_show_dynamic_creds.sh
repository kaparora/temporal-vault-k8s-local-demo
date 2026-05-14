#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T3: After Vault order run"
note "Terminal 1 should be running 02_T1_ports.sh."
note "Terminal 2 should be running 05_T2_worker_vault_db.sh."

step "Reset demo data"
run make reset-data

step "Show a generated database credential"
note "This uses the narrow order-validate helper role."
run make vault-read-db-creds

step "Trigger the happy-path order"
run make run-order ORDER_ID=ORD-001

step "What to show"
note "Worker logs should show Vault-generated Postgres usernames."
note "This removes static DB credentials from the worker runtime path."
