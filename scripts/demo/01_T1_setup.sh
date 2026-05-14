#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T1: Set up the local demo stack"
note "This runs make setup, which does the full local bootstrap:"
note "1. Install Python dependencies."
note "2. Create the kind Kubernetes cluster."
note "3. Deploy Postgres, Temporal, Temporal UI, and Vault."
note "4. Wait for the services to become ready."
note "5. Seed the order demo database."
note "6. Configure Vault database roles."
note "7. Configure Vault Transit and create the limited trigger token."
note "8. Configure Vault Kubernetes auth for the worker ServiceAccount."
note "If the cluster already exists, this command will fail. Use make down for a full fresh start."
run make setup

step "Show cluster status"
run make status

note "Next in Terminal 1: ./scripts/demo/02_T1_ports.sh"
