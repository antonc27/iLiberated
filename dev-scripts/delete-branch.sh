#!/bin/bash
# Usage: dev-scripts/delete-branch.sh [--remote REMOTE] BRANCH
#
# Delete BRANCH from its remote and locally (if it exists). Search all
# configured remotes, or select one with --remote. Run this separately when
# ready to remove the branch, for example after squash-cherry-pick.sh succeeds.
# Refuse checked-out branches, unpushed local commits, and remote changes
# during deletion. This script does not import changes or create a commit.
set -euo pipefail

die() {
    echo "Error: $*" >&2
    exit 1
}

USAGE="Usage: $0 [--remote REMOTE] BRANCH (without a remote prefix)"
REQUESTED_REMOTE=
SOURCE_BRANCH=
while [ $# -gt 0 ]; do
    case "$1" in
        --remote)
            [ $# -ge 2 ] && [ -n "$2" ] || die "$USAGE"
            [ -z "$REQUESTED_REMOTE" ] || die "Specify --remote only once. $USAGE"
            REQUESTED_REMOTE=$2
            shift
            ;;
        -*) die "Unknown option: $1. $USAGE" ;;
        *)
            if [ -n "$SOURCE_BRANCH" ] || [ -z "$1" ]; then
                die "$USAGE"
            fi
            SOURCE_BRANCH=$1
            ;;
    esac
    shift
done
[ -n "$SOURCE_BRANCH" ] || die "$USAGE"
SOURCE_REF="refs/heads/$SOURCE_BRANCH"
if ! git check-ref-format --branch "$SOURCE_BRANCH" > /dev/null 2>&1 ||
    ! git check-ref-format "$SOURCE_REF" > /dev/null 2>&1; then
    die "Invalid branch name: $SOURCE_BRANCH"
fi

git rev-parse --git-dir > /dev/null

for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer BISECT_START; do
    [ ! -e "$(git rev-parse --git-path "$state")" ] ||
        die "Finish the existing Git operation before running this script."
done
UNMERGED_FILES=$(git ls-files --unmerged)
[ -z "$UNMERGED_FILES" ] ||
    die "Resolve existing conflicts before deleting a branch."

# A squash does not preserve ancestry, so deletion needs -D. Check all
# worktrees, including this one, before contacting the remote.
while IFS= read -r line; do
    [ "$line" != "branch $SOURCE_REF" ] ||
        die "Branch $SOURCE_BRANCH is checked out in a worktree; switch away from it first."
done < <(git worktree list --porcelain)

# Inspect live refs, since remote-tracking branches may be stale or unfetched.
REMOTES=$(git remote)
[ -n "$REMOTES" ] || die "No Git remotes are configured."
if [ -n "$REQUESTED_REMOTE" ]; then
    git remote get-url -- "$REQUESTED_REMOTE" > /dev/null 2>&1 ||
        die "Unknown remote: $REQUESTED_REMOTE"
    REMOTES=$REQUESTED_REMOTE
fi
SOURCE_REMOTE=
MATCH_COUNT=0
MATCHING_REMOTES=
FAILED_REMOTES=
CHECKED_REMOTES=
while IFS= read -r remote; do
    CHECKED_REMOTES="${CHECKED_REMOTES:+$CHECKED_REMOTES, }$remote"
    if REMOTE_BRANCHES=$(git ls-remote --heads -- "$remote" "$SOURCE_REF"); then
        while read -r _object_id ref; do
            if [ "$ref" = "$SOURCE_REF" ]; then
                SOURCE_REMOTE=$remote
                MATCH_COUNT=$((MATCH_COUNT + 1))
                MATCHING_REMOTES="${MATCHING_REMOTES:+$MATCHING_REMOTES, }$remote"
                break
            fi
        done <<< "$REMOTE_BRANCHES"
    else
        FAILED_REMOTES="${FAILED_REMOTES:+$FAILED_REMOTES, }$remote"
    fi
done <<< "$REMOTES"
[ -z "$FAILED_REMOTES" ] ||
    die "Could not check remotes: $FAILED_REMOTES. Fix access or select a remote with --remote REMOTE."
[ "$MATCH_COUNT" -gt 0 ] ||
    die "Branch $SOURCE_BRANCH was not found on the checked remotes: $CHECKED_REMOTES. Check the branch name with git ls-remote --heads REMOTE."
[ "$MATCH_COUNT" -eq 1 ] ||
    die "Branch $SOURCE_BRANCH exists on multiple remotes: $MATCHING_REMOTES. Select one with --remote REMOTE."

REMOTE_REF="refs/remotes/$SOURCE_REMOTE/$SOURCE_BRANCH"
echo "Fetching $SOURCE_BRANCH from $SOURCE_REMOTE."
git fetch --no-tags --no-recurse-submodules -- "$SOURCE_REMOTE" "+$SOURCE_REF:$REMOTE_REF" ||
    die "Could not fetch $SOURCE_REMOTE/$SOURCE_BRANCH; no branches deleted."
SOURCE_HEAD=$(git rev-parse --verify "$REMOTE_REF^{commit}")
LOCAL_HEAD=$(git rev-parse --verify "$SOURCE_REF" 2>/dev/null || true)
if [ -n "$LOCAL_HEAD" ]; then
    git merge-base --is-ancestor "$LOCAL_HEAD" "$SOURCE_HEAD" ||
        die "Local $SOURCE_BRANCH contains commits absent from $SOURCE_REMOTE; keeping both branches."
fi

# Keep the local branch if remote deletion fails. The lease prevents deleting
# commits pushed by someone else since the fetch, even after a force-push.
if [ "$(git rev-parse --verify "$SOURCE_REF" 2>/dev/null || true)" != "$LOCAL_HEAD" ]; then
    die "Local $SOURCE_BRANCH changed; skipping branch deletion."
fi
if ! git push --no-follow-tags --recurse-submodules=no \
    --force-with-lease="$SOURCE_REF:$SOURCE_HEAD" -- "$SOURCE_REMOTE" ":$SOURCE_REF"; then
    die "Deletion from $SOURCE_REMOTE failed; local source branch kept."
fi
if [ -n "$LOCAL_HEAD" ]; then
    [ "$(git rev-parse --verify "$SOURCE_REF" 2>/dev/null || true)" = "$LOCAL_HEAD" ] ||
        die "Remote branch deleted, but local branch changed; keeping it."
    git branch -D -- "$SOURCE_BRANCH" ||
        die "Remote branch deleted, but local branch deletion failed."
fi
echo "Deleted $SOURCE_REMOTE/$SOURCE_BRANCH and the local branch (if it existed)."
