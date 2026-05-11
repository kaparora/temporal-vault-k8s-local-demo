#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "Before Transit: sensitive payloads visible in Temporal history"
note "This uses the normal Kubernetes worker on orders-tq."

step "Reset demo data"
run make db-init

step "Deploy the plaintext Kubernetes worker"
run make worker-k8s

step "Trigger the happy-path order"
run make trigger ORDER_ID=ORD-001

step "What to show in Temporal UI"
note "Inspect workflow input and activity inputs."
note "You should be able to see avery.stone@example.com."
note "You should be able to see 42 Market Street, Berlin."
note "You should be able to see tok_demo_visa_4242_sensitive."
