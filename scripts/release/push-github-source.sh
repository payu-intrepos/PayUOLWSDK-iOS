#!/usr/bin/env bash
#
# Push current HEAD to GitHub remote (source branch — release.sh only pushes tags by default).
# Uses same remote name as release.sh (GITHUB_REMOTE, default: github).
# Debug: VERBOSE=1
#
# Env:
#   GITHUB_REMOTE   default: github
#   GITHUB_BRANCH   destination ref (default: current branch name)
#   DRY_RUN=1       Print git push only
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT}"

REMOTE="${GITHUB_REMOTE:-github}"
BRANCH="${GITHUB_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"

log() { echo "[push-github-source] $*"; }
vlog() {
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    echo "[push-github-source][verbose] $*"
  fi
}

if [[ "${BRANCH}" == "HEAD" ]]; then
  log "ERROR: detached HEAD; set GITHUB_BRANCH explicitly"
  exit 2
fi

vlog "REMOTE=${REMOTE} BRANCH=${BRANCH}"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  if ! git remote get-url "${REMOTE}" >/dev/null 2>&1; then
    log "WARN: git remote '${REMOTE}' not configured — real push would fail until you: git remote add ${REMOTE} <url>"
  fi
  log "dry-run: git push ${REMOTE} HEAD:${BRANCH}"
  exit 0
fi

if ! git remote get-url "${REMOTE}" >/dev/null 2>&1; then
  log "ERROR: git remote '${REMOTE}' not configured."
  log "Fix: git remote add ${REMOTE} https://github.com/<org>/<repo>.git"
  exit 2
fi

log "pushing HEAD -> ${REMOTE} ${BRANCH}"
git push "${REMOTE}" "HEAD:${BRANCH}"

log "done."
