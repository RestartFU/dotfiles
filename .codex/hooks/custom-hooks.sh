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

When the user only says "push", treat it as "commit and push": commit all current repo changes, then push, unless the user explicitly limits scope or says not to commit.

When given a github link, use git or gh CLI to access /read it
When there is an AGENTS.md, CLAUDE.md or any other agent file at the project root, or at the root of code you're modifying, take it into context
When user tells you to commit and push, push all current repo changes unless explicitly told to limit scope.
If the user modifies a file, treat that edit as authoritative user intent. Do not modify it back, revert it, or "restore" my previous version just because I did not make that change. Re-read the file and work with the user's latest contents.
EOF
