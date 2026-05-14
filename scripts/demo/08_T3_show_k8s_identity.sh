#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T3: Show Kubernetes auth"
note "Terminal 2 should have run 07_T2_worker_k8s_auth.sh."
note "The Kubernetes worker should be the only worker polling orders-tq."

step "Reset demo data"
run make reset-data

step "Trigger the happy-path order"
run make run-order ORDER_ID=ORD-001

step "Show worker logs"
run make logs-worker

step "What to show"
note "Expected log signal: vault_auth_method=kubernetes."
note "The order-worker name is workload identity and policy, not a broad database role."
