---
name: running-review-loops
description: Use when the user asks for a review loop, iterative review and fixes, work until clean or approved, CodeRabbit plus Codex approval, or asks to be notified, pinged, or alerted when work stops.
---

# Running Review Loops

## Contract

Review and fix the scoped PR until CodeRabbit and Codex on GitHub clear the same exact revision. Missing, stale, ambiguous, or inaccessible state is not clearance. Any code change invalidates both approval gates.

Interpret “notify me,” “ping me,” and “alert me” as a Discord webhook request. Notification must say where work stopped, why it is stopping, and enough context to act.

**REQUIRED SUB-SKILL:** Use `github:gh-address-comments` for GitHub review-thread reads, replies, and individual resolution.

## Loop

1. Freeze original scope, repository, PR, base, current head SHA, changed files, and acceptance checks.
2. Require an existing pushed GitHub PR. Review-loop authority permits in-scope fixes, normal commits/pushes to its branch, reviewer reactions/replies/thread resolution, and review-trigger comments. It does not permit PR creation/merge, force-push, base changes, or scope expansion.
3. Verify CodeRabbit's effective `reviews.request_changes_workflow` is `true`, including inherited/central settings. Its default is `false`, and CodeRabbit does not emit `APPROVED` without it. Use the existing configuration response or request `@coderabbitai configuration`. If approval workflow is disabled or cannot be proven, stop with a configuration blocker. Do not change repository/organization settings without separate authority.
4. Run focused tests and relevant broader checks. Commit and push candidate revision.
5. For each reviewer, classify final-SHA state as `completed`, `in-flight`, or `absent` using PR reviews, review threads, timeline/comments/reactions, and checks:
   - Accept a completed automatic review only with evidence its analysis completed after the final push; never trigger a duplicate.
   - If already running or in-flight, wait and poll. A 👀 reaction to a trigger without a later review is in-flight.
   - Immediately after a push, allow automatic review a quiet window and recheck before declaring it absent.
   - Only when absent, trigger once for that SHA: `@codex review` for Codex or `@coderabbitai full review` for CodeRabbit. Record trigger comment ID and SHA. Never re-trigger while that run lacks terminal output; report a stalled reviewer instead of spamming commands.
6. Read every new finding. Verify it against code, tests, contracts, and scope.
7. Handle reviewer threads, then resolve them individually:
   - Correct finding: react thumbs up (`+1`), reply that it is valid, implement the smallest fix, push it, reply with commit/test evidence, then resolve the thread.
   - Incorrect finding: react thumbs down (`-1`), reply with concrete technical evidence explaining why, then resolve the thread.
   - Do not use `@coderabbitai resolve` as a shortcut; it can hide unaddressed threads.
8. Any fix creates a new head SHA. Return to step 4 and obtain fresh reviews.

For reactions on inline review comments:

```bash
gh api -X POST "repos/$repo/pulls/comments/$comment_id/reactions" -f content='+1'
gh api -X POST "repos/$repo/pulls/comments/$comment_id/reactions" -f content='-1'
```

Reply to the exact inline comment, not only the PR conversation. Use thread node IDs and GraphQL `resolveReviewThread` for individual resolution.

## Final gates

Both gates must refer to unchanged final head SHA and have no unresolved actionable threads:

- **CodeRabbit:** analysis completed for the final SHA after the last push, and a final-SHA CodeRabbit review is `APPROVED`, with no later changes/findings. Approval alone is not analysis evidence: resolving threads can produce an approval before CodeRabbit reviews the pushed fix. If analysis completion is missing, wait for or request a review even when an approval exists.
- **Codex on GitHub:** a fresh final-SHA Codex review completed. Pass on GitHub `APPROVED`; also pass on a completed `COMMENTED` review with no active P0/P1 findings, because OpenAI documents Codex GitHub review as a standard review that flags P0/P1 issues but does not promise an `APPROVED` state. Report this accurately as “Codex clean,” not a GitHub approval.

Do not trust walkthroughs, summary comments, “review completed,” no new comments, reactions alone, or reviews on older SHAs.

After two non-converging fix cycles, reclassify remaining findings. Continue only for in-scope blockers. Stop when resolution requires a new contract, architecture, migration, owner boundary, or authority.

## Stop notification

Standing opt-in: user established during this personal skill's creation that every successful review loop sends one Discord webhook without needing a repeated “notify me” request. This opt-in covers the configured webhook and review-loop success only. Other tasks require an explicit notification request.

Notify exactly once immediately before terminal response when:

- dual final-SHA gates pass, even without explicit notification request; or
- user requested notification and work stops as completed, approved, blocked, failed, or cancelled.

```bash
RUNNING_REVIEW_LOOPS_SKILL="${CODEX_HOME:-$HOME/.codex}/skills/running-review-loops"
"$RUNNING_REVIEW_LOOPS_SKILL/scripts/notify-discord" \
  --status approved \
  --where 'owner/repo#123 @ final-sha' \
  --why 'CodeRabbit approved and Codex GitHub review is clean on final SHA' \
  --context 'Tests: ...; findings handled: ...; PR: ...'
```

Message contract:

- `Where`: repository/PR/branch/SHA, or task/checkpoint for non-review work.
- `Why stopping`: dual clearance or exact blocker/failure/cancellation/completion reason.
- `Context`: result, tests, findings/replies, outstanding work, and next action.

Send operational summaries only. Never include code excerpts, secrets, credentials, private issue/review bodies, or raw logs in webhook content.

Notifier places the user ping only in top-level message content. It renders status, location, stop reason, and context in a status-colored Discord embed; never put the ping inside the embed because embed mentions do not notify.

Notifier requests Discord server confirmation. It retries only an explicit short rate limit; ambiguous network/server failures are not retried because Discord webhooks provide no idempotency key. If delivery fails, report failure; never claim notification success without zero exit status.

## Quick reference

| State | Action |
|---|---|
| `request_changes_workflow` not proven true | Stop with configuration blocker |
| Automatic review running | Wait; do not trigger another |
| Final code changed | Invalidate both gates; rerun both |
| Valid reviewer finding | `+1`, fix, prove, reply, resolve |
| Invalid reviewer finding | `-1`, explain with evidence, resolve |
| Reviewer unavailable/stalled | Stop blocked; never infer clearance |
| User said “notify me” | Ping on every terminal stop |
| Both final-SHA gates pass | Ping once, then return final response |
