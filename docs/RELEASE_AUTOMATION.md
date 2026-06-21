# OLW iOS SDK release automation (CocoaPods + SPM)

This document describes the automation under `scripts/release/` and the root [`versions.yaml`](../versions.yaml). **Rules applied:** no secrets in repo, local/runtime credentials, single source of truth for versions, reproducible SPM via `Package.resolved`.

## What was automated

| Step | Tool | Purpose |
|------|------|--------|
| Version sync | `ruby scripts/release/sync-versions.rb` | Writes internal pod versions + CocoaPods external pins + SPM pins into the three `.podspec` files, [`Package.swift`](../Package.swift) (between `GENERATED_SPM_DEPS` markers), and legacy `PayUIndia-*-SDK-Release.sh` `podVersion=…` lines. |
| Preflight | `ruby scripts/release/preflight.rb` | Read-only `git ls-remote --tags` for configured repos; `pod spec cat` / `pod trunk info` for transitive dependency hints. |
| Plan (offline) | `ruby scripts/release/print-trunk-plan.rb` | Prints `git_source_url`, unique tags from `internal_pods`, trunk order → podspec → version, and xcframework names — **no network**. |
| Manifest validation | `ruby scripts/release/validate-manifest.rb` | Offline checks: semver-ish internal versions, podspecs exist, `s.version` matches yaml (warn if drift), `trunk_push_order` ⊆ `internal_pods`, `cocoapods_external` keys appear in some OLW podspec, `spm.packages` non-empty, xcframework dirs (optional `--require-xcframeworks`). |
| Suggest next internal versions | `ruby scripts/release/suggest-internal-versions.rb` | **`git ls-remote --tags`** on `metadata.git_source_url` + **alpha.N → alpha.N+1** bump suggestion; prints YAML snippet — **does not write** `versions.yaml` (you still choose policy). |
| Git author from manifest | `ruby scripts/release/git-author-from-manifest.rb` | Prints `export GIT_AUTHOR_*` / `GIT_COMMITTER_*` from **`release.git_author`** when `GIT_AUTHOR_EMAIL` is unset; used by `commit-version-bump.sh` via `eval`. |
| SPM resolve + stage | `scripts/release/resolve-spm.sh` | Runs **`swift package resolve`** and **`git add`** `Package.resolved` / `Package.swift` if changed (no commit). |
| Push source branch to GitHub | `scripts/release/push-github-source.sh` | **`git push $GITHUB_REMOTE HEAD:$GITHUB_BRANCH`** (default remote `github`, branch = current); `DRY_RUN=1` supported. |
| Artifact copy | `scripts/release/sync-artifacts.sh` | Copies built `.xcframework` bundles from `ARTIFACTS_SRC` into the repo root (names from `versions.yaml` → `release.vendored_xcframeworks`). |
| Trunk wait / poll | `ruby scripts/release/wait-for-pod.rb` | After each `pod trunk push`, optionally wait until the version shows up (`pod trunk info` and/or `pod spec cat`) before pushing the next pod. |
| Release commit (optional) | `scripts/release/commit-version-bump.sh` | Stages synced files and runs one `git commit` using `GIT_AUTHOR_*` / `GIT_COMMITTER_*` for that command only (no global `~/.gitconfig` change). |
| Interactive wizard | `scripts/release/interactive-release.sh` | **TTY only:** prompts for optional steps (suggest versions, per-pod bumps, `ARTIFACTS_SRC`, sync, SPM resolve, validate, commit, push source, `release.sh`). Option **4** requires typing **`YES`** to enable trunk. CI should call other scripts directly, not this wizard. |
| Patch internal version | `ruby scripts/release/patch-internal-pod-version.rb POD VERSION` | Line-preserving edit of one **`internal_pods`** entry in `versions.yaml` (used by the wizard). |

## `versions.yaml` schema

Top-level keys:

- **`metadata`** — `git_source_url` documents the public CocoaPods `:git` URL (not rewritten by sync today; keep in sync manually if the repo moves).
- **`internal_pods`** — Map of pod name → semver string. These values become `s.version` in each matching `.podspec`, drive `PayUIndia-*-SDK-Release.sh`, and define **git tags** the orchestrator creates (unique set of versions).
- **`cocoapods_external`** — Map of dependency pod name → requirement string (e.g. `"~> 4.0"`, `"4.1.0.alpha.1"`). Internal cross-links are **not** listed here: **Core → PayUIndia-OLWParams-SDK** and **UI → PayUIndia-OLWCore-SDK** are injected from `internal_pods`.
- **`spm.packages`** — Map of logical package name → `{ url, pin }`. Supported `pin.kind` values:
  - **`from`** — `{ kind: from, version: "2.1.1" }` → `.package(..., from: "2.1.1")`
  - **`exact`** — `{ kind: exact, version: "4.0.0" }` → `.package(..., .exact("4.0.0"))`
  - **`revision`** — `{ kind: revision, value: "<git-sha>" }` → `.package(..., revision: "...")`
  - **`branch`** — `{ kind: branch, branch: "alpha" }` → `.package(..., branch: "alpha")`
- **`release`** — Optional automation metadata:
  - **`git_author`** — Optional `{ name, email }`. When set, `commit-version-bump.sh` runs `eval "$(ruby scripts/release/git-author-from-manifest.rb)"` so release commits use PayU identity **without changing global `~/.gitconfig`**. Environment variables still override when already set.
  - **`trunk_push_order`** — Array of internal pod names in dependency order (default: Params → Core → UI). Used by `release.sh` for `pod trunk push`.
  - **`vendored_xcframeworks`** — Filenames under the repo root used by `sync-artifacts.sh` when copying from `ARTIFACTS_SRC`.
- **`preflight`** — Optional `git_tag_discovery` list (`label`, `repo_url`) and `pod_spec_cat` pod names.

### SPM: branch vs revision (important)

SwiftPM requires **one requirement style per package URL** across the whole graph. `PayUIndia-PPI-SDK` depends on several PayU packages using **branch `alpha`**. If this repo pins the same URL with **`revision`**, resolution fails with an error similar to:

> required using two different revision-based requirements … and alpha

For that reason, alpha-train packages that PPI also pulls by branch are configured with **`kind: branch` / `branch: alpha`** in [`versions.yaml`](../versions.yaml). Reproducibility for consumers comes from **committing [`Package.resolved`](../Package.resolved)** after a successful `swift package resolve` on the release machine.

## GitHub (public) vs GitLab (private)

1. Keep `origin` (or your default) pointing at **GitLab** for day-to-day development.
2. Add a second remote for GitHub releases, e.g.:

   ```bash
   git remote add github https://github.com/payu-intrepos/PayUOLWSDK-iOS.git
   ```

3. The orchestrator pushes **tags** to the remote named by **`GITHUB_REMOTE`** (default `github`).

### Release commit author (optional)

For commits that should show PayU release identity (not your personal GitLab author), either:

**A)** Add **`release.git_author`** to [`versions.yaml`](../versions.yaml) (loaded automatically by `commit-version-bump.sh` when `GIT_AUTHOR_EMAIL` is unset), or  
**B)** Export for a one-off commit:

```bash
export GIT_AUTHOR_NAME="PayU Mobile App"
export GIT_AUTHOR_EMAIL="payumoneyapp@payumoney.com"
export GIT_COMMITTER_NAME="PayU Mobile App"
export GIT_COMMITTER_EMAIL="payumoneyapp@payumoney.com"
./scripts/release/commit-version-bump.sh
```

`scripts/release/release.sh` does **not** auto-commit by default; run `commit-version-bump.sh` after `sync-versions.rb` (and after staging any large `.xcframework` dirs if needed).

### Push source (commits) to GitHub

`release.sh` only pushes **tags** to `GITHUB_REMOTE`. To push the **branch** with your release commit:

```bash
./scripts/release/push-github-source.sh
# Or: GITHUB_BRANCH=release/1.0 DRY_RUN=1 ./scripts/release/push-github-source.sh
```

### CocoaPods trunk safety gate

**`pod trunk push` only runs when `RELEASE_ALLOW_TRUNK=1`** (and not with `--dry-run` / `--skip-trunk`). This avoids accidental publishes from a bare `./scripts/release/release.sh`. For a real publish:

```bash
export RELEASE_ALLOW_TRUNK=1
# Optional: wait for each pod to become visible before pushing the next (20 min–1 h propagation)
export WAIT_AFTER_TRUNK=1
export WAIT_POD_INTERVAL=60
export WAIT_POD_MAX_SEC=7200
./scripts/release/release.sh
```

### Copying built xcframeworks into the release clone

Point `ARTIFACTS_SRC` at the folder that **directly contains** the `.xcframework` directories (same names as in `release.vendored_xcframeworks`):

```bash
export ARTIFACTS_SRC="/absolute/path/to/build/output"
./scripts/release/sync-artifacts.sh
# Dry run: DRY_RUN=1 ./scripts/release/sync-artifacts.sh
```

## Interactive wizard (TTY)

Yes — **prompting for inputs during a script is normal automation** for human-driven releases. Use when you want the machine to **walk the steps** and you **answer at each gate** (paths, y/n, version strings).

```bash
chmod +x scripts/release/interactive-release.sh
./scripts/release/interactive-release.sh
```

**Requirements:** run from a **real terminal** (stdin must be a TTY). If stdin is piped or CI, the script exits with a hint to call `sync-versions.rb` / `release.sh` directly.

**Behaviour (high level):**

1. Shows **`print-trunk-plan.rb`** output.  
2. Optional **`suggest-internal-versions.rb`**.  
3. Optional **per-pod** version edits → writes **`versions.yaml`** via **`patch-internal-pod-version.rb`** (preserves comments elsewhere).  
4. Optional **`ARTIFACTS_SRC`** → **`sync-artifacts.sh`**.  
5. Always runs **`sync-versions.rb`** after any yaml/artifact step.  
6. Optional **`resolve-spm.sh`**, **`validate-manifest.rb`**, **`commit-version-bump.sh`**, **`push-github-source.sh`**.  
7. Menu for **`release.sh`**: dry-run, skip-trunk, skip, or **full trunk** (only if you type **`YES`**).

**Not prompted (still your responsibility):** CocoaPods Keychain session, GitHub SSH/HTTPS credentials, **external/SPM pins** in `versions.yaml` (wizard does not edit those yet — edit file or extend scripts if needed).

## Credentials (no passwords in the repository)

| Action | How |
|--------|-----|
| `pod trunk push` | One-time `pod trunk register`; CocoaPods stores session in the **macOS Keychain**. No `POD_TRUNK_TOKEN` in git. |
| `git push` to GitHub | **SSH agent** or HTTPS with OS credential helper — interactive at runtime. |
| `git ls-remote` | Read-only; **no token** for public GitHub URLs. |

## Commands cheat sheet

```bash
# Interactive wizard (TTY): prompts for paths / y-n / versions, then runs the same tools
chmod +x scripts/release/interactive-release.sh
./scripts/release/interactive-release.sh

# 0) Offline: print tags, trunk order, podspec paths (no network)
ruby scripts/release/print-trunk-plan.rb

# 0b) Offline: validate versions.yaml vs podspecs / xcframeworks
ruby scripts/release/validate-manifest.rb

# 0c) Network: suggest next x.y.z.alpha.N (prints YAML snippet; does not write files)
ruby scripts/release/suggest-internal-versions.rb

# 1) Optional: inspect remote tags + pod metadata (network required for git/pod)
ruby scripts/release/preflight.rb

# 2) Apply versions.yaml → podspecs + Package.swift + legacy release scripts
ruby scripts/release/sync-versions.rb

# 2b) Resolve SPM and stage Package.resolved (+ Package.swift if changed)
chmod +x scripts/release/resolve-spm.sh
./scripts/release/resolve-spm.sh

# 3) Full pipeline (after editing versions.yaml / xcframeworks)
chmod +x scripts/release/release.sh
./scripts/release/release.sh

# Dry-run publish steps only (still runs sync, resolve, lint; prints trunk steps without pushing)
./scripts/release/release.sh --dry-run

# Everything except trunk (lint, tags, etc.) — no RELEASE_ALLOW_TRUNK needed
./scripts/release/release.sh --skip-trunk

# Sync only (fast edit cycle)
./scripts/release/release.sh --sync-only
```

Environment knobs: `VERBOSE=1`, `GITHUB_REMOTE`, `RELEASE_ALLOW_TRUNK`, `WAIT_AFTER_TRUNK`, `WAIT_POD_INTERVAL`, `WAIT_POD_MAX_SEC`, `SKIP_*` flags (see `release.sh --help`).

Manual wait between pods (without re-running the full script):

```bash
ruby scripts/release/wait-for-pod.rb PayUIndia-OLWParams-SDK 1.0.0.alpha.4 --interval 60 --max-wait-seconds 3600
```

## CocoaPods nested dependencies (PPI ↔ Analytics, etc.)

`preflight.rb` prints `s.dependency` lines when `pod spec cat` succeeds. If a pod is not registered on the machine’s spec repos, run `pod repo update` or inspect the podspec on GitHub, then align **`cocoapods_external`** in `versions.yaml` so `pod lib lint` finds a **non-empty intersection** of constraints with transitive pods (same policy as in the approved plan: align pins or coordinate upstream releases).

## Checklist before you publish

1. Edit **`versions.yaml`** (internal + external + SPM). Optionally run **`ruby scripts/release/suggest-internal-versions.rb`** and paste/adjust.
2. Run **`ruby scripts/release/sync-versions.rb`** and review `git diff` (podspecs, `Package.swift`, release scripts).
3. Run **`./scripts/release/resolve-spm.sh`** (or `swift package resolve`) and commit **`Package.resolved`** when satisfied (resolve script stages files; you still `commit`).
4. Run **`ruby scripts/release/validate-manifest.rb`** (`--require-xcframeworks` before trunk if binaries must be present).
5. Run **`pod lib lint`** (or `./scripts/release/release.sh` without skip flags).
6. Push code: **`./scripts/release/push-github-source.sh`** (or your usual flow). Ensure **`github`** remote exists for tags.
7. **`pod trunk push`**: set `RELEASE_ALLOW_TRUNK=1` and run `./scripts/release/release.sh` (or push manually in the same order as `release.trunk_push_order`). Optionally set `WAIT_AFTER_TRUNK=1` to poll between pushes.

## What remains manual (by design)

- **Policy**: semver bump strategy (patch vs minor vs alpha train), and **`cocoapods_external` / `spm`** pins that satisfy PPI and other graphs — scripts only *suggest* / *validate*, they do not choose product policy.
- **Building** `.xcframework` binaries (Xcode / CI) — automation copies and validates presence, not compilation.
- **Org process**: branch protection, PR review, CocoaPods **trunk owners** / Keychain session, and **`RELEASE_ALLOW_TRUNK=1`** when you intentionally publish.
- **Coordination** with upstream teams when constraints conflict — use `preflight.rb` + `validate-manifest.rb` to reduce surprises, not eliminate communication.

## What we need from you (org-specific)

- Confirm **tagging policy** (today: one git tag per unique internal semver, shared tag when Core and UI share a version).
- Confirm **CocoaPods trunk** owner for all three pod names.
- If `pod spec cat` should always work offline, add a private specs repo or document `pod repo add` for PayU internal pods.
