#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T3: After Transit"
note "Terminal 2 should have run 10_T2_worker_transit.sh."
note "This uses the separate orders-tq-transit task queue."
note "The trigger client uses a limited Transit token."
note "The Kubernetes worker uses Vault Kubernetes auth."

step "Reset demo data"
run make reset-data

step "Trigger the encrypted-payload workflow"
run make run-order-transit ORDER_ID=ORD-001

step "Show worker logs"
run make logs-worker

step "What to show in Temporal UI"
note "Sensitive payload values should no longer be visible directly."
note "Encoded payloads should show metadata such as binary/vault-transit."
