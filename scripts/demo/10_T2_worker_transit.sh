#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T2: Transit-enabled Kubernetes worker"
note "This switches the Kubernetes worker to the Transit task queue."
note "The trigger client and worker will both use the Vault Transit payload codec."
note "The limited Transit trigger token is created by 01_T1_setup.sh or 13_T3_reset.sh."

step "Deploy the Transit-enabled worker"
run make worker-transit

step "Worker is ready"
note "Next in Terminal 3: ./scripts/demo/11_T3_show_transit_encryption.sh"
