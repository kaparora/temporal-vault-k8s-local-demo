#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T1: Start port-forwards"
note "Keep this terminal running for the rest of the demo."
note "Temporal UI: http://localhost:8080"

run make ports
