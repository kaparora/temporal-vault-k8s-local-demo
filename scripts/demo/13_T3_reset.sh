#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T3: Reset demo data and Vault configuration"
note "This keeps the cluster, but refreshes the database rows and Vault config."

run make reset

step "Show cluster status"
run make status
