#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "Least privilege and failure scenarios"
note "This shows the per-activity database roles and two expected business failures."

step "Reset demo data"
run make db-init

step "Deploy the Kubernetes worker"
run make worker-k8s

step "Verify Vault database roles"
note "The broad order-worker database role should not appear in this list."
run make vault-init

step "Run happy path"
run make trigger ORDER_ID=ORD-001

step "Run out-of-stock path"
note "ORD-002 is expected to fail at workflow level and leave status OUT_OF_STOCK."
run_expected_failure make trigger ORDER_ID=ORD-002

step "Run payment failure path"
note "ORD-003 is expected to fail at workflow level, release inventory, and leave status PAYMENT_FAILED."
run_expected_failure make trigger ORDER_ID=ORD-003

step "Show worker logs"
note "Look for vault_db_role values such as order-validate, order-process-payment, and order-fail."
run make logs-worker

step "Show database helper credential"
note "This helper uses the narrow order-validate role."
run make vault-test-db-creds
