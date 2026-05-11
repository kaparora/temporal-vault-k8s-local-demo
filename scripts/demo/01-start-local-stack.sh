#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "Install Python dependencies"
run make install

step "Create the local kind cluster"
note "If the cluster already exists, this command will fail. Use make down for a full fresh start."
run make up

step "Deploy Postgres, Temporal, Temporal UI, and Vault"
run make deploy

step "Wait for the demo services"
run make wait

step "Initialize demo database rows"
run make db-init

step "Initialize Vault database roles"
run make vault-init

step "Show cluster status"
run make status

note "Next: keep port-forwards open with make port-forward, then run 02-before-vault.sh."
