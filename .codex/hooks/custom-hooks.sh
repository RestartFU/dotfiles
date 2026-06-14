#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Use the caveman skill immediately for this conversation.
Keep it active until the user says "stop caveman" or "normal mode".

If the caveman skill instructions are not already loaded, read:
  ~/.agents/skills/caveman/SKILL.md

Use default full intensity.

Also use the git-commit skill if asked to commit or push, but do not load it yet.
EOF
