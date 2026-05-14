#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T3: Before Vault order run"
note "Terminal 1 should be running 02_T1_ports.sh."
note "Terminal 2 should be running 03_T2_worker_static_db.sh."

step "Reset demo data"
run make reset-data

step "Trigger the happy-path order"
run make run-order ORDER_ID=ORD-001

step "What to show"
note "Temporal UI should show a completed ORD-001 workflow."
note "The worker is using static Postgres credentials."
note "Temporal UI should show sensitive workflow/activity payload data."
