#!/usr/bin/env bash
#
# Interactive release wizard: prompts for inputs and runs existing release scripts.
# Use from a real terminal (TTY). Does not store answers in files except versions.yaml
# when you confirm internal pod version changes.
# Debug: VERBOSE=1
#
# Non-TTY: exits with instructions (CI should call sync-versions.rb / release.sh directly).
#
# Usage:
#   chmod +x scripts/release/interactive-release.sh
#   ./scripts/release/interactive-release.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT}"

log() { echo "[interactive-release] $*"; }

usage() {
  cat <<'EOF'
Interactive OLW release wizard (TTY only). Guides you through:
  plan → optional suggest → optional per-pod version edits → optional artifact copy
  → sync-versions → optional SPM resolve → optional validate → optional commit
  → optional push source → optional release.sh (dry-run / skip-trunk / full)

For automation without prompts, call the underlying scripts from CI instead
(see docs/RELEASE_AUTOMATION.md).

Options:
  -h, --help   This help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) log "Unknown option: $1"; usage; exit 2 ;;
  esac
done

if [[ ! -t 0 ]]; then
  log "ERROR: stdin is not a terminal. Run this script from Terminal/iTerm (not piped)."
  log "For CI, use: ruby scripts/release/sync-versions.rb && scripts/release/release.sh ..."
  exit 2
fi

confirm_yes_default() {
  # Default YES on empty
  local prompt=$1
  read -r -p "${prompt} [Y/n] " _ans || true
  [[ -z "${_ans}" || "${_ans}" =~ ^[Yy] ]]
}

confirm_no_default() {
  # Default NO on empty
  local prompt=$1
  read -r -p "${prompt} [y/N] " _ans || true
  [[ "${_ans}" =~ ^[Yy] ]]
}

log "=== PayU OLW interactive release ==="
log "Repo: ${ROOT}"
echo

log "--- Current plan (offline) ---"
ruby "${SCRIPT_DIR}/print-trunk-plan.rb" || true
echo

if confirm_no_default "Run suggest-internal-versions.rb (needs network)?"; then
  ruby "${SCRIPT_DIR}/suggest-internal-versions.rb" || log "WARN: suggest script failed (network?)"
  echo
fi

if confirm_no_default "Update internal_pods versions in versions.yaml now?"; then
  while IFS=$'\t' read -r pod cur; do
    [[ -z "${pod}" ]] && continue
    read -r -p "  New version for ${pod} [${cur}] (Enter=keep): " newv
    if [[ -n "${newv}" ]]; then
      ruby "${SCRIPT_DIR}/patch-internal-pod-version.rb" "${pod}" "${newv}"
    fi
  done < <(ruby -ryaml -e "YAML.load_file('${ROOT}/versions.yaml').fetch('internal_pods', {}).each { |k,v| puts \"#{k}\t#{v}\" }")
  echo
fi

read -r -p "ARTIFACTS_SRC (folder containing .xcframework bundles, empty=skip copy): " _src
if [[ -n "${_src}" ]]; then
  export ARTIFACTS_SRC="${_src}"
  if confirm_no_default "Dry-run artifact copy first?"; then
    DRY_RUN=1 "${SCRIPT_DIR}/sync-artifacts.sh" || true
  fi
  if confirm_yes_default "Run sync-artifacts.sh (real copy)?"; then
    "${SCRIPT_DIR}/sync-artifacts.sh"
  fi
  echo
fi

log "Running sync-versions.rb …"
ruby "${SCRIPT_DIR}/sync-versions.rb"
echo

if confirm_yes_default "Run resolve-spm.sh (swift package resolve + git add)?"; then
  "${SCRIPT_DIR}/resolve-spm.sh" || log "WARN: resolve-spm failed"
  echo
fi

if confirm_no_default "Run validate-manifest.rb --require-xcframeworks?"; then
  ruby "${SCRIPT_DIR}/validate-manifest.rb" --require-xcframeworks || log "WARN: validate-manifest reported errors"
else
  if confirm_yes_default "Run validate-manifest.rb (warnings ok if xcframeworks not built yet)?"; then
    ruby "${SCRIPT_DIR}/validate-manifest.rb" || log "WARN: validate-manifest reported errors"
  fi
fi
echo

if confirm_no_default "Run commit-version-bump.sh (git commit; author from versions.yaml if set)?"; then
  "${SCRIPT_DIR}/commit-version-bump.sh"
  echo
fi

if confirm_no_default "Push source branch to GitHub (push-github-source.sh)?"; then
  read -r -p "  GITHUB_BRANCH [current: $(git rev-parse --abbrev-ref HEAD)]: " _br
  export GITHUB_BRANCH="${_br:-$(git rev-parse --abbrev-ref HEAD)}"
  if confirm_no_default "  Dry-run push only?"; then
    DRY_RUN=1 "${SCRIPT_DIR}/push-github-source.sh"
  else
    "${SCRIPT_DIR}/push-github-source.sh"
  fi
  echo
fi

log "--- release.sh (lint / tags / optional trunk) ---"
echo "  1) Dry-run (no real tag push / no trunk)"
echo "  2) Skip trunk (lint + tags push)"
echo "  3) Exit — you run release.sh yourself later"
echo "  4) Full pipeline INCLUDING pod trunk (requires typing YES)"
read -r -p "Choose [1/2/3/4]: " _rel
case "${_rel}" in
  1)
    "${SCRIPT_DIR}/release.sh" --dry-run
    ;;
  2)
    "${SCRIPT_DIR}/release.sh" --skip-trunk
    ;;
  3)
    log "Stopped before release.sh. When ready:"
    log "  RELEASE_ALLOW_TRUNK=1 ./scripts/release/release.sh   # real trunk"
    ;;
  4)
    read -r -p "Type YES (capital letters) to set RELEASE_ALLOW_TRUNK=1 and run full release.sh: " _yes
    if [[ "${_yes}" == "YES" ]]; then
      export RELEASE_ALLOW_TRUNK=1
      if confirm_no_default "Enable WAIT_AFTER_TRUNK (poll between trunk pushes)?"; then
        export WAIT_AFTER_TRUNK=1
      fi
      "${SCRIPT_DIR}/release.sh"
    else
      log "Aborted — did not type YES."
    fi
    ;;
  *)
    if [[ -n "${_rel}" ]]; then
      log "Unknown choice; not running release.sh."
    else
      log "Empty choice; not running release.sh."
    fi
    log "For full pipeline with trunk: RELEASE_ALLOW_TRUNK=1 ./scripts/release/release.sh"
    ;;
esac

echo
log "=== Wizard finished ==="
log "If publishing to CocoaPods trunk, confirm versions then: RELEASE_ALLOW_TRUNK=1 ./scripts/release/release.sh"
