#!/usr/bin/env bash
#
# OLW SDK release orchestrator: sync versions, SPM resolve, pod lib lint, git tag/push, trunk push.
# Credentials: never stored in-repo — use Keychain (pod trunk) and SSH/HTTPS prompts as usual.
# Debug: VERBOSE=1 prints extra traces (similar intent to debugPrint in Swift sample code).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT}"

GITHUB_REMOTE="${GITHUB_REMOTE:-github}"
DRY_RUN=0
SKIP_PREFLIGHT=0
SKIP_SPM=0
SKIP_LINT=0
SKIP_GIT=0
SKIP_TRUNK=0
SYNC_ONLY=0

usage() {
  cat <<'EOF'
Usage: scripts/release/release.sh [options]

Options:
  --dry-run          Skip git tag/push and pod trunk push (sync, resolve, lint still run).
  --sync-only        Only run versions.yaml -> podspecs / Package.swift / release scripts sync.
  --skip-preflight   Skip ruby scripts/release/preflight.rb
  --skip-spm         Skip swift package resolve
  --skip-lint        Skip pod lib lint
  --skip-git         Skip git tag + push
  --skip-trunk       Skip pod trunk push
  -h, --help         This help

Environment:
  GITHUB_REMOTE      Name of git remote for public GitHub (default: github). Add with:
                       git remote add github https://github.com/<org>/<repo>.git
  GIT_AUTHOR_NAME    Optional override for release commits (see docs/RELEASE_AUTOMATION.md)
  GIT_AUTHOR_EMAIL   Optional override for release commits
  VERBOSE            Set to 1 for extra logging
  RELEASE_ALLOW_TRUNK  Must be 1 to run real `pod trunk push` (ignored with --dry-run or --skip-trunk).
  WAIT_AFTER_TRUNK   If 1, after each successful trunk push run wait-for-pod.rb before the next push.
  WAIT_POD_INTERVAL  Seconds between wait-for-pod polls (default: 30)
  WAIT_POD_MAX_SEC   Max seconds to wait per pod (default: 3600)

Typical flow:
  1) Edit versions.yaml
  2) ruby scripts/release/preflight.rb   # optional: tags + pod metadata
  3) scripts/release/release.sh          # full pipeline (trunk push requires RELEASE_ALLOW_TRUNK=1)
EOF
}

log() {
  echo "[release] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --sync-only) SYNC_ONLY=1 ;;
    --skip-preflight) SKIP_PREFLIGHT=1 ;;
    --skip-spm) SKIP_SPM=1 ;;
    --skip-lint) SKIP_LINT=1 ;;
    --skip-git) SKIP_GIT=1 ;;
    --skip-trunk) SKIP_TRUNK=1 ;;
    -h|--help) usage; exit 0 ;;
    *) log "Unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

run() {
  log "exec: $*"
  "$@"
}

# Side-effectful steps that honour --dry-run (remote publish / tag push).
run_publish() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "dry-run: $*"
    return 0
  fi
  log "exec: $*"
  "$@"
}

ruby_sync() {
  run ruby "${ROOT}/scripts/release/sync-versions.rb"
}

if [[ "${SKIP_PREFLIGHT}" -eq 0 && "${SYNC_ONLY}" -eq 0 ]]; then
  if ! run ruby "${ROOT}/scripts/release/preflight.rb"; then
    log "WARN: preflight exited non-zero (often missing private pod specs on this machine). Continuing."
  fi
fi

ruby_sync

if [[ "${SYNC_ONLY}" -eq 1 ]]; then
  log "sync-only complete. Review git diff, then run swift package resolve / pod lib lint as needed."
  exit 0
fi

if [[ "${SKIP_SPM}" -eq 0 ]]; then
  run swift package resolve
fi

if [[ "${SKIP_LINT}" -eq 0 ]]; then
  # Order: Params -> Core -> UI (matches CocoaPods dependency chain).
  run pod lib lint "${ROOT}/PayUIndia-OLWParams-SDK.podspec" --allow-warnings --verbose
  run pod lib lint "${ROOT}/PayUIndia-OLWCore-SDK.podspec" --allow-warnings --verbose
  run pod lib lint "${ROOT}/PayUIndia-OLWUI-SDK.podspec" --allow-warnings --verbose
fi

if [[ "${SKIP_GIT}" -eq 0 ]]; then
  MANIFEST="${ROOT}/versions.yaml"
  if [[ ! -f "${MANIFEST}" ]]; then
    log "versions.yaml missing"
    exit 1
  fi
  # Unique tag names only (Core and UI may share the same semver).
  export OLW_VERSIONS_YAML="${MANIFEST}"
  mapfile -t VERSIONS < <(ruby -ryaml -e "v=YAML.load_file(ENV['OLW_VERSIONS_YAML'])['internal_pods'] || {}; puts v.values.uniq.to_a.sort.join(\"\n\")")
  if [[ "${#VERSIONS[@]}" -lt 1 ]]; then
    log "Could not read internal_pods from versions.yaml"
    exit 1
  fi

  for ver in "${VERSIONS[@]}"; do
    [[ -z "${ver}" ]] && continue
    if git rev-parse -q --verify "refs/tags/${ver}" >/dev/null; then
      log "tag already exists locally: ${ver} (skip create)"
    else
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "dry-run: git tag ${ver}"
      else
        log "creating tag ${ver}"
        git tag "${ver}"
      fi
    fi
    if git remote get-url "${GITHUB_REMOTE}" >/dev/null 2>&1; then
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        log "dry-run: git push ${GITHUB_REMOTE} ${ver}"
      else
        log "pushing tag ${ver} -> ${GITHUB_REMOTE}"
        git push "${GITHUB_REMOTE}" "${ver}"
      fi
    else
      log "WARN: git remote '${GITHUB_REMOTE}' not configured; skipping push. Use: git remote add ${GITHUB_REMOTE} <url>"
    fi
  done
fi

if [[ "${SKIP_TRUNK}" -eq 0 ]]; then
  if [[ "${DRY_RUN}" -eq 0 && "${RELEASE_ALLOW_TRUNK:-0}" != "1" ]]; then
    log "Skipping pod trunk push: set RELEASE_ALLOW_TRUNK=1 to publish (safety gate)."
    log "Hint: use --dry-run to print trunk steps, or --skip-trunk to silence this message."
  else
    MANIFEST="${ROOT}/versions.yaml"
    export OLW_MANIFEST="${MANIFEST}"
    # Dependency order: Params -> Core -> UI (override via versions.yaml → release.trunk_push_order).
    mapfile -t TRUNK_PODS < <(ruby -ryaml -e '
      m = YAML.load_file(ENV.fetch("OLW_MANIFEST"))
      o = m.dig("release", "trunk_push_order")
      o ||= %w[PayUIndia-OLWParams-SDK PayUIndia-OLWCore-SDK PayUIndia-OLWUI-SDK]
      Array(o).each { |p| puts p }
    ')
    WAIT_IV="${WAIT_POD_INTERVAL:-30}"
    WAIT_MX="${WAIT_POD_MAX_SEC:-3600}"

    for pod in "${TRUNK_PODS[@]}"; do
      [[ -z "${pod}" ]] && continue
      podspec="${ROOT}/${pod}.podspec"
      if [[ ! -f "${podspec}" ]]; then
        log "ERROR: missing podspec for trunk order entry: ${podspec}"
        exit 1
      fi
      ver="$(ruby -ryaml -e "m=YAML.load_file(ENV.fetch(%q{OLW_MANIFEST})); puts m.dig(%q{internal_pods}, ARGV[0])" "${pod}")"
      if [[ -z "${ver}" ]]; then
        log "ERROR: internal_pods.${pod} missing in versions.yaml"
        exit 1
      fi

      log "pod trunk push ${pod} (version ${ver}; Keychain session)"
      run_publish pod trunk push "${podspec}" --allow-warnings --verbose

      if [[ "${DRY_RUN}" -eq 0 && "${WAIT_AFTER_TRUNK:-0}" == "1" && "${RELEASE_ALLOW_TRUNK:-0}" == "1" ]]; then
        log "WAIT_AFTER_TRUNK: waiting for ${pod} ${ver} to appear on trunk…"
        run ruby "${ROOT}/scripts/release/wait-for-pod.rb" "${pod}" "${ver}" --interval "${WAIT_IV}" --max-wait-seconds "${WAIT_MX}"
      fi
    done
  fi
fi

log "release pipeline finished."
