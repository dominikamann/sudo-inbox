#!/usr/bin/env bash
# Run shellcheck and the bats suite in an Ubuntu container.
set -euo pipefail
cd "$(dirname "$0")/.."
docker build -q -t sudo-inbox-test -f test/Dockerfile test >/dev/null 2>&1 \
  || { echo "docker build failed" >&2; exit 1; }
docker run --rm -v "$PWD":/w sudo-inbox-test bash -c \
  'shellcheck sudo-inbox test/helpers/bin/sudo && bats "${@:-test}"' _ "$@"
