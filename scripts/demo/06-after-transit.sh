#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "After Transit: sensitive payloads encrypted in Temporal history"
note "This uses the separate orders-tq-transit task queue."
note "The trigger client and worker both use the Vault Transit payload codec."

step "Reset demo data"
run make db-init

step "Deploy the Transit-enabled Kubernetes worker"
run make worker-k8s-transit

step "Trigger the encrypted-payload workflow"
run make trigger-transit ORDER_ID=ORD-001

step "Show worker logs"
run make logs-worker

step "What to show in Temporal UI"
note "Sensitive payload values should no longer be visible directly."
note "Encoded payloads should show metadata such as binary/vault-transit."
