#!/usr/bin/env bash
#
# Posts the current place build to a Discord channel for the Studio workstream.
#
# Usage:
#   export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
#   make notify
#   ./scripts/notify-discord.sh "Conductor health rebalanced"
#
# The webhook URL is a secret: it grants anyone who has it the ability to post
# to that channel. Keep it in your environment or a local .env, never in git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLACE="$ROOT/build/BulletHell.rbxlx"
NOTE="${1:-}"

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  echo "DISCORD_WEBHOOK_URL is not set. Export it, then re-run." >&2
  exit 1
fi

if [[ ! -f "$PLACE" ]]; then
  echo "No build found at $PLACE. Run 'make build' first." >&2
  exit 1
fi

COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo "uncommitted")"
BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
SUBJECT="$(git -C "$ROOT" log -1 --pretty=%s 2>/dev/null || echo "no commit")"
SIZE="$(du -h "$PLACE" | cut -f1)"

MESSAGE="**Bullet Hell build** \`${BRANCH}@${COMMIT}\` (${SIZE})
${SUBJECT}"
if [[ -n "$NOTE" ]]; then
  MESSAGE="${MESSAGE}
${NOTE}"
fi

# jq is not assumed; the payload is simple enough to escape by hand.
PAYLOAD=$(printf '%s' "$MESSAGE" | python3 -c 'import json,sys; print(json.dumps({"content": sys.stdin.read()}))')

curl -fsS \
  -F "payload_json=$PAYLOAD" \
  -F "file=@${PLACE};filename=BulletHell.rbxlx" \
  "$DISCORD_WEBHOOK_URL" > /dev/null

echo "Posted ${PLACE} (${SIZE}) to Discord."
