---
name: release
description: Cut a new MemoDismiss release. Use when the user says "发版", "release", "出个新版本", "打 tag", or wants to publish the current main as a tagged release that triggers the GitHub Actions build. Handles precondition checks, version bump selection, annotated tag creation, tag push, and monitoring the release workflow to completion.
---

# MemoDismiss Release Skill

Automates publishing a new MemoDismiss release. The GitHub Actions workflow in `.github/workflows/release.yml` only fires on `v*` tag pushes — this skill is the single entry point for creating that tag correctly.

## Process (follow in order, no steps skipped)

### 1. Precondition checks

Run **in this order** (do not parallelize — the fetch must complete before the ahead/behind checks). **If any fails, stop and report to the user — do not attempt to auto-fix:**

```bash
git rev-parse --abbrev-ref HEAD          # expect: main
git status --porcelain                   # expect: empty
git fetch --tags origin                  # MUST run before the ahead/behind checks below
git rev-list HEAD..origin/main --count   # expect: 0 (we're not behind)
git rev-list origin/main..HEAD --count   # expect: 0 (we're not ahead — everything pushed)
```

If the user is ahead of origin, ask whether to push first. If behind, stop and tell them to pull. If the tree is dirty, stop and show `git status`.

### 2. Compute the next version

```bash
git tag -l 'v*' --sort=-v:refname | head -5
```

Default bump is **patch** (`v1.0.0 → v1.0.1`). Look at the commits since the last tag:

```bash
LAST_TAG=$(git tag -l 'v*' --sort=-v:refname | head -1)
git log "$LAST_TAG..HEAD" --oneline
```

Decide the bump from commit content:

- Breaking changes / removed features → **major** (`v1.x.y → v2.0.0`)
- New user-visible features / behavior additions → **minor** (`v1.x.y → v1.(x+1).0`)
- Fixes, docs, internal refactors only → **patch** (`v1.x.y → v1.x.(y+1)`)

Show the user your proposed version **and** the one-line log of commits since the last tag, then ask: "Proceed with `vX.Y.Z`? (or specify another)". Always confirm — never tag silently.

If there are zero commits since the last tag, stop and tell the user there's nothing to release.

### 3. Check tag doesn't already exist

```bash
git tag -l "vX.Y.Z"                             # expect: empty
gh release view vX.Y.Z >/dev/null 2>&1 \
  && echo "ALREADY PUBLISHED — STOP" \
  || echo "not published yet — ok to proceed"
```

If the tag exists locally or the release is already published, stop. Don't overwrite.

### 4. Write a tag message

Draft a short annotated-tag message from the commits since the last tag. Format:

```
Release vX.Y.Z

- <user-visible change 1>
- <user-visible change 2>
- ...
```

Focus on what users experience, not internal refactors. Show the drafted message to the user and ask for approval before tagging. Use a HEREDOC when creating the tag to preserve newlines.

### 5. Create and push the tag

```bash
git tag -a vX.Y.Z -F - <<'EOF'
<message from step 4>
EOF

git push origin vX.Y.Z
```

### 6. Monitor the Actions run

The workflow is named **Release** (from `.github/workflows/release.yml`). After pushing the tag, GitHub needs a few seconds to register the run; poll for it before watching:

```bash
# Resolve the run id triggered by THIS tag (don't blindly grab "latest" —
# an unrelated workflow run could win the race).
TAG=vX.Y.Z
for i in 1 2 3 4 5; do
  RUN_ID=$(gh run list --workflow=release.yml --limit 10 \
    --json databaseId,headBranch,event \
    --jq ".[] | select(.event==\"push\" and .headBranch==\"$TAG\") | .databaseId" \
    | head -1)
  [ -n "$RUN_ID" ] && break
  sleep 3
done

if [ -z "$RUN_ID" ]; then
  echo "Could not find a workflow run for $TAG — check Actions tab manually."
  exit 1
fi

gh run watch "$RUN_ID" --exit-status   # blocks until success/failure
```

If the run fails, show the user `gh run view "$RUN_ID" --log-failed` output and stop.

### 7. Confirm the release

```bash
gh release view vX.Y.Z --json url,assets --jq '{url, assets: [.assets[].name]}'
```

Report to the user:

- The release URL
- The artifact name (expect `MemoDismiss.app.zip`)
- Reminder that users upgrading need to re-authorize Accessibility (see README "Updating to a new version" section) because ad-hoc signing gives a new CDHash each release

## Rules

- **Never push a tag without explicit user approval on both version and message.**
- **Never delete or move an existing tag.** If the user wants to redo a release, they must delete it manually first; do not do it for them.
- **Don't proceed past a failed precondition.** No auto-pull, no auto-commit, no auto-stash. Report and stop.
- **Don't attempt a fix if the Actions run fails.** Show logs, stop, let the user decide.
- When showing commits since last tag, always use `--oneline` to keep output tight.
- The version must match `^v\d+\.\d+\.\d+$`. No pre-release suffixes (`-rc1`, `-beta`) unless the user explicitly requests them — the workflow filter is `v*` but convention here is plain semver.
