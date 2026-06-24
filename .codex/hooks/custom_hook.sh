#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
If the user modifies a file, treat that edit as authoritative user intent. Do not modify it back, revert it, or "restore" my previous version just because I did not make that change. Re-read the file and work with the user's latest contents.
EOF
