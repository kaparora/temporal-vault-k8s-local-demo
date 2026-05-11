#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "${ROOT_DIR}"

step() {
  printf "\n== %s ==\n" "$1"
}

note() {
  printf "   %s\n" "$1"
}

run() {
  printf "\n$ %s\n" "$*"
  "$@"
}

run_expected_failure() {
  printf "\n$ %s\n" "$*"
  set +e
  "$@"
  status=$?
  set -e

  if [[ ${status} -eq 0 ]]; then
    printf "Expected this command to fail, but it succeeded.\n" >&2
    return 1
  fi

  printf "Command failed as expected with exit code %s.\n" "${status}"
}
