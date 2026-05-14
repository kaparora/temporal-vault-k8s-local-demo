#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T1: Clean up the local demo cluster"
note "This deletes the kind cluster and all local demo resources."
note "Port-forward terminals will stop once the cluster is gone."

run make down
