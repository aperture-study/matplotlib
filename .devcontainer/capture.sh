#!/usr/bin/env bash
# End-of-session data capture. Run this as the LAST step of a study session.
#
#   bash .devcontainer/capture.sh p03
#
# The codespace belongs to the participant and cannot be read afterwards, so everything we need
# has to leave over git: Aperture writes its session timeline to perf/logs/sessions/<ts>_<id>/
# (see packages/opencode/src/aperture/study-log.ts in the Aperture repo), and the participant's
# own code changes are what the session was about. Both go up on one branch.
#
# The facilitator must FETCH AND VERIFY this branch before any cleanup. Never remove a
# participant from the org/repo before then — that deletes their codespace and its contents.
set -euo pipefail
cd "$(dirname "$0")/.."

ID="${1:-}"
if [ -z "$ID" ]; then
  echo "usage: bash .devcontainer/capture.sh <participant-id>   e.g. p03" >&2
  exit 1
fi

BRANCH="participant-${ID}"

git add -A
if git diff --cached --quiet; then
  echo "Nothing to capture — no changes and no session logs?" >&2
  exit 1
fi

git -c user.name="Aperture Study" -c user.email="study@aperture.invalid" \
    commit -q -m "participant ${ID} session"
git push -u origin "HEAD:${BRANCH}"

echo
echo "Pushed ${BRANCH}. Session folders captured:"
git show --stat --oneline HEAD -- perf/logs/sessions | sed -n '2,$p'
echo
echo "Tell the facilitator to fetch ${BRANCH} and confirm before anything is deleted."
