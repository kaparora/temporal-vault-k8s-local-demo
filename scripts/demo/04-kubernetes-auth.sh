#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "Kubernetes auth: workload identity for the worker"
note "This deploys the order worker as a Kubernetes pod."
note "The pod authenticates to Vault with the order-worker ServiceAccount JWT."

step "Reset demo data"
run make db-init

step "Deploy the Kubernetes worker"
run make worker-k8s

step "Trigger the happy-path order"
run make trigger ORDER_ID=ORD-001

step "Show worker logs"
run make logs-worker

step "What to show"
note "Expected log signal: vault_auth_method=kubernetes."
note "The order-worker name is workload identity and policy, not a broad database role."
