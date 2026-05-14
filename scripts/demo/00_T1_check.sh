#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "T1: Check required local tools"
note "The demo needs Docker, kind, kubectl, Python tooling through uv, and make."

for tool in docker kind kubectl uv make; do
  if command -v "${tool}" >/dev/null 2>&1; then
    note "found ${tool}: $(command -v "${tool}")"
  else
    printf "Missing required tool: %s\n" "${tool}" >&2
    exit 1
  fi
done

step "Check Docker connectivity"
note "kind needs Docker to create and manage the local Kubernetes cluster."
docker version >/dev/null
note "Docker is reachable."
