#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T2: Before Vault worker"
note "This local worker uses static Postgres credentials."
note "Keep this terminal running while you run 04_T3_show_security_problems.sh in Terminal 3."
note "Expected log signal: db_credential_source=static"

run make worker-static
