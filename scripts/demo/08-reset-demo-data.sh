#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "Reset demo data and Vault configuration"
note "This keeps the cluster, but refreshes the database rows and Vault config."

run make db-init
run make vault-init
run make vault-init-transit
run make vault-enable-k8s-auth

step "Show cluster status"
run make status
