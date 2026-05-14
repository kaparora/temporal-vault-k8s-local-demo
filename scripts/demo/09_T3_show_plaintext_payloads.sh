#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T3: Before Transit"
note "Terminal 2 should have run 07_T2_worker_k8s_auth.sh."
note "This uses the normal Kubernetes worker on orders-tq."

step "Reset demo data"
run make reset-data

step "Trigger the happy-path order"
run make run-order ORDER_ID=ORD-001

step "What to show in Temporal UI"
note "Inspect workflow input and activity inputs."
note "You should be able to see avery.stone@example.com."
note "You should be able to see 42 Market Street, Berlin."
note "You should be able to see tok_demo_visa_4242_sensitive."
