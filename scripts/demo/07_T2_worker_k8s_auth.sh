#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T2: Kubernetes auth worker"
note "Stop 05_T2_worker_vault_db.sh with Ctrl-C before running this script."
note "This builds and loads the worker image once, then deploys the worker pod."
note "The pod authenticates to Vault with the order-worker ServiceAccount JWT."
note "Vault setup was already done by setup/reset, so no root token is passed here."
note "Expected log signal after Terminal 3 runs an order: vault_auth_method=kubernetes."

step "Build and load the worker image"
run make demo-build-worker

step "Deploy the Kubernetes worker"
run make worker-k8s-deploy

step "Worker is ready"
note "Next in Terminal 3: ./scripts/demo/08_T3_show_k8s_identity.sh"
