#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Use the caveman skill immediately for this conversation.
Keep it active until the user says "stop caveman" or "normal mode".

If the caveman skill instructions are not already loaded, read:
  ~/.agents/skills/caveman/SKILL.md

Use default full intensity.

When asked to commit, create a git commit, push committed changes, or handle /commit, load and use:
  ~/.agents/skills/git-commit/SKILL.md
EOF
