#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LOCK="$ROOT_DIR/upstream.lock.toml"
failed=0

check_repo() {
    section=$1
    repository=$(awk -v section="[$section]" '
        $0 == section { found=1; next }
        found && /^\[/ { exit }
        found && /^repository = / { gsub(/^repository = "|".*$/, ""); print; exit }
    ' "$LOCK")
    locked=$(awk -v section="[$section]" '
        $0 == section { found=1; next }
        found && /^\[/ { exit }
        found && /^commit = / { gsub(/^commit = "|".*$/, ""); print; exit }
    ' "$LOCK")
    current=$(git ls-remote "$repository" HEAD | awk '{print $1}')
    if [[ "$locked" != "$current" ]]; then
        printf '%s drift: locked=%s current=%s\n' "$section" "$locked" "$current"
        failed=1
    else
        printf '%s current: %s\n' "$section" "$locked"
    fi
}

check_repo go_raknet
check_repo gophertunnel
check_repo dragonfly
exit "$failed"

