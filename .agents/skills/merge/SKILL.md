---
name: merge
description: >-
  Merge requested changes for the Dart Stylizer repository through its GitHub pull-request workflow. Invoke only when the user has explicitly requested merging or chosen Merge Change; do not invoke for review, preparation, passing checks, or skill installation.
disable-model-invocation: true
metadata:
  delta-action: land
---

# Merge Dart Stylizer changes

Use this workflow only for an explicit request to merge the current changes. Once invoked for that request, proceed through the workflow rather than asking whether the user wants to merge again.

## Preconditions and scope

1. Confirm the repository is `nguyenthang1597/dart_stylizer`, the destination is `main`, and the configured publication remote is `origin`.
2. Inspect the working tree, current branch, and `origin/main` before changing anything. Preserve unrelated edits, including uncommitted edits that are not part of the requested change. Do not reset, discard, stash destructively, or commit unrelated work.
3. Establish the exact files and behavior requested. Stop if the scope cannot be separated safely from unrelated changes.
4. Check for applicable project requirements in `Agents.md`, `README.md`, and `CHANGELOG.md`. New behavior must have tests; update documentation or the changelog when the change warrants it. There is currently no repository requirement for signed commits, a contributor agreement, or an approving review, but do not bypass any requirement discovered in the live repository settings.

## Prepare the pull request

1. Work from a focused non-`main` branch. If the requested changes are already on a suitable branch, use it; otherwise create a descriptive branch without changing or losing unrelated work.
2. Review the diff, confirm it contains only the requested changes, and create a clear commit. Do not use an interactive editor. If the requested changes are uncommitted together with unrelated edits and cannot be separated safely, stop and report the blocker.
3. Run the repository's local verification before publication:

   ```sh
   dart pub get
   dart format .
   dart analyze
   dart test
   ```

   These commands are the project's required completion checks in `Agents.md` (the corresponding CI commands are defined in `.github/workflows/ci-release.yml`). Do not treat formatting, analysis, or tests as successful if the command fails.
4. Push the focused branch to `origin` and create or update a pull request targeting `main` with `gh`. Include a concise human-readable summary and testing summary; do not fabricate issue references, release notes, or human-authored statements.
5. Ensure the pull request's final commit is the one being merged. If additional changes or conflict resolution alter the commit, rerun the local checks and wait for checks on that new commit.

## Resolve conflicts safely

The conflict preference is automatic resolution when the intended result is clear, and pausing for unsafe or ambiguous conflicts.

- If conflicts occur, inspect each conflict and the surrounding project behavior. Resolve automatically only when the correct result is unambiguous and preserves unrelated work.
- After any resolution, review the complete diff and rerun `dart format .`, `dart analyze`, and `dart test`.
- Pause and report the files and competing intents when a conflict could change behavior, discard unrelated work, or cannot be resolved confidently. Do not force-push or merge around the conflict.

## Verify GitHub requirements before merging

1. Inspect the pull request through `gh` and verify that it targets `main`, has no unresolved review conversations, and is mergeable.
2. Verify the required branch-protection check `Format, analyze, and test` is completed successfully for the exact pull-request head commit. Pending, failing, skipped, missing, stale, or unverifiable required checks are not success. The workflow defining this check is `.github/workflows/ci-release.yml`; its test job runs `dart pub get`, `dart format --set-exit-if-changed .`, `dart analyze`, and `dart test`.
3. Do not treat unrelated release jobs as required for an ordinary pull request. Release builds and publication run only for version tags and are not a substitute for the required test check.
4. Confirm the pull request is not behind a changed `main` in a way that invalidates required checks. If GitHub requires an update, update the branch, rerun all affected checks, and verify the new head again.
5. Stop for authentication failures, insufficient permissions, changed scope, unresolved conversations, missing or unverifiable checks, or any repository-protection condition that cannot be satisfied safely.

## Merge and verify

1. Merge the approved pull request with GitHub's regular merge-commit method, matching the repository's existing merge history. Use `gh pr merge` non-interactively; do not use squash, rebase, force-push, or direct pushes to `main`.
2. After the merge command reports success, verify through `gh` and Git that the pull request is merged and its merge commit is reachable from `origin/main`. Fetch the updated `origin/main` before making this determination.
3. If the merge does not complete, report that the changes remain unmerged and identify the concrete blocker. Never describe a prepared branch, published pull request, or passing checks as a completed merge.
