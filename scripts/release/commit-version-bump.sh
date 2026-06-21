#!/usr/bin/env bash
#
# Optional: stage version bump files and create one git commit with PayU release author.
# Set author via env (do not commit global ~/.gitconfig — per-invocation only).
# Debug: VERBOSE=1
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT}"

# Optional: use release.git_author from versions.yaml when env not already set (no ~/.gitconfig change).
if [[ -z "${GIT_AUTHOR_EMAIL:-}" ]]; then
  # shellcheck disable=SC1090
  eval "$(ruby "${SCRIPT_DIR}/git-author-from-manifest.rb")"
fi

log() { echo "[commit-version-bump] $*"; }

usage() {
  cat <<'EOF'
Stages common release files and runs `git commit`.

Author (pick one):
  A) Set GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL (and COMMITTER same as author), or
  B) Add release.git_author in versions.yaml — this script loads it when env is unset.

Optional:
  COMMIT_MESSAGE   Override default message
  DRY_RUN=1       Print git commands only

Typical sequence:
  ruby scripts/release/sync-versions.rb
  ./scripts/release/commit-version-bump.sh
EOF
}

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  log "dry-run mode"
fi

if [[ -z "${GIT_AUTHOR_EMAIL:-}" || -z "${GIT_AUTHOR_NAME:-}" ]]; then
  log "WARN: GIT_AUTHOR_NAME / GIT_AUTHOR_EMAIL still unset — commit will use your default git identity (add release.git_author to versions.yaml or export env)."
fi

MSG="${COMMIT_MESSAGE:-chore(release): bump versions from versions.yaml}"

FILES=(
  "versions.yaml"
  "PayUIndia-OLWParams-SDK.podspec"
  "PayUIndia-OLWCore-SDK.podspec"
  "PayUIndia-OLWUI-SDK.podspec"
  "Package.swift"
  "Package.resolved"
  "PayUIndia-OLWParams-SDK-Release.sh"
  "PayUIndia-OLWCore-SDK-Release.sh"
  "PayUIndia-OLWUI-SDK-Release.sh"
)

to_add=()
for f in "${FILES[@]}"; do
  if [[ -f "${ROOT}/${f}" ]]; then
    to_add+=("${f}")
  fi
done

# Large binaries: stage xcframeworks explicitly when ready, e.g.:
#   git add PayUOLWParamKit.xcframework PayUOLWCoreKit.xcframework PayUOLWUIKit.xcframework

if [[ "${#to_add[@]}" -lt 1 ]]; then
  log "ERROR: nothing to stage"
  exit 1
fi

run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "dry-run: $*"
  else
    log "exec: $*"
    "$@"
  fi
}

run git add -- "${to_add[@]}"
run git commit -m "${MSG}"

log "done. Next: push branch / tags per your process, then ./scripts/release/release.sh --skip-trunk (or with trunk after RELEASE_ALLOW_TRUNK=1)."
