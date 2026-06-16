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

When given a github link, use git or gh CLI to access /read it
When there is an AGENTS.md, CLAUDE.md or any other agent file at the project root, or at the root of code you're modifying, take it into context
EOF
