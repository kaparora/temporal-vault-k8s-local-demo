#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "Before Vault: static database credentials"
note "Start make worker in another terminal before running this script."
note "Expected worker log signal: db_credential_source=static"

step "Reset demo data"
run make db-init

step "Trigger the happy-path order"
run make trigger ORDER_ID=ORD-001

step "What to show"
note "Temporal UI should show a completed ORD-001 workflow."
note "The worker is using the static Postgres username and password from environment variables."
