#!/usr/bin/env bash
#
# Runs swift package resolve and stages Package.resolved (and Package.swift if changed) for commit.
# Does not commit. Debug: VERBOSE=1
#
# Optional env:
#   DRY_RUN=1     Print actions only
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT}"

log() { echo "[resolve-spm] $*"; }
vlog() {
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    echo "[resolve-spm][verbose] $*"
  fi
}

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  log "dry-run: would run swift package resolve and git add Package.resolved Package.swift"
  exit 0
fi

log "running swift package resolve…"
vlog "cwd: ${ROOT}"
swift package resolve

to_add=()
if [[ -f "${ROOT}/Package.resolved" ]]; then
  to_add+=("Package.resolved")
fi
if [[ -f "${ROOT}/Package.swift" ]]; then
  to_add+=("Package.swift")
fi

if [[ "${#to_add[@]}" -lt 1 ]]; then
  log "WARN: Package.resolved missing after resolve"
  exit 0
fi

log "staging: ${to_add[*]}"
git add -- "${to_add[@]}"

if git diff --cached --quiet; then
  log "nothing to stage (no changes to Package.swift / Package.resolved)"
else
  log "staged SPM lockfiles. Next: git commit (e.g. ./scripts/release/commit-version-bump.sh or your message)."
fi
