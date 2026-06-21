#!/usr/bin/env bash
#
# Copy built .xcframework bundles into this repo root (same layout as .podspec vendored_frameworks).
# Does not commit or push — run after your local/SDK build produces artifacts.
# Debug: VERBOSE=1 prints each copy (similar intent to debugPrint in Swift).
#
# Required env:
#   ARTIFACTS_SRC   Absolute path to folder containing the xcframeworks (e.g. .../build/Release-iphoneos)
#
# Optional:
#   DRY_RUN=1       Print what would be copied, do not write
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

log() { echo "[sync-artifacts] $*"; }
vlog() {
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    echo "[sync-artifacts][verbose] $*"
  fi
}

usage() {
  cat <<'EOF'
Usage:
  export ARTIFACTS_SRC="/path/to/folder/containing/xcframeworks"
  ./scripts/release/sync-artifacts.sh

Copies (from versions.yaml → release.vendored_xcframeworks):
  $ARTIFACTS_SRC/<name>.xcframework  →  $ROOT/<name>.xcframework

Environment:
  ARTIFACTS_SRC   Required source directory
  DRY_RUN=1       Show planned copies only
  VERBOSE=1       Extra logging
EOF
}

if [[ -z "${ARTIFACTS_SRC:-}" ]]; then
  log "ERROR: set ARTIFACTS_SRC to the directory that contains the built .xcframework folders."
  usage
  exit 2
fi

if [[ ! -d "${ARTIFACTS_SRC}" ]]; then
  log "ERROR: ARTIFACTS_SRC is not a directory: ${ARTIFACTS_SRC}"
  exit 2
fi

MANIFEST="${ROOT}/versions.yaml"
if [[ ! -f "${MANIFEST}" ]]; then
  log "ERROR: missing ${MANIFEST}"
  exit 1
fi

# Read xcframework names from versions.yaml (release.vendored_xcframeworks); fallback to OLW trio.
export OLW_MANIFEST="${MANIFEST}"
mapfile -t FRAMEWORKS < <(ruby -ryaml -e '
  m = YAML.load_file(ENV.fetch("OLW_MANIFEST"))
  xs = m.dig("release", "vendored_xcframeworks")
  xs ||= %w[PayUOLWParamKit.xcframework PayUOLWCoreKit.xcframework PayUOLWUIKit.xcframework]
  Array(xs).each { |x| puts x }
')

if [[ "${#FRAMEWORKS[@]}" -lt 1 ]]; then
  log "ERROR: could not resolve framework list"
  exit 1
fi

for name in "${FRAMEWORKS[@]}"; do
  [[ -z "${name}" ]] && continue
  src="${ARTIFACTS_SRC%/}/${name}"
  dest="${ROOT}/${name}"

  if [[ ! -d "${src}" ]]; then
    log "ERROR: missing source bundle: ${src}"
    exit 1
  fi

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log "dry-run: would sync ${src} -> ${dest}"
    continue
  fi

  vlog "removing old destination if present: ${dest}"
  rm -rf "${dest}"
  log "copying ${name} …"
  # Ditto preserves bundle metadata on macOS
  ditto "${src}" "${dest}"
done

log "done. Review: ls -la \"${ROOT}\"/*.xcframework"
