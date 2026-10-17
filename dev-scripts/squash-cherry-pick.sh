#!/bin/bash
# Usage: dev-scripts/squash-cherry-pick.sh [--remote REMOTE] BRANCH
#
# Search all configured remotes for BRANCH, or select one with --remote.
# Fetch BRANCH, squash its changes since the common ancestor, and cherry-pick
# them as one commit onto the current branch, with the author reset to the
# current Git committer. Requires a clean working tree.
# Source branches are kept. To remove them afterward, run delete-branch.sh
# with the same branch name (and --remote, if needed).
# The current branch is not pushed.
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

CURRENT_REF=$(git symbolic-ref --quiet HEAD) ||
    die "Check out the destination branch first (HEAD is detached)."
CURRENT_BRANCH=${CURRENT_REF#refs/heads/}
[ "$SOURCE_REF" != "$CURRENT_REF" ] ||
    die "The source and destination branches must be different."
START_HEAD=$(git rev-parse --verify HEAD)

for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer BISECT_START; do
    [ ! -e "$(git rev-parse --git-path "$state")" ] ||
        die "Finish the existing Git operation before running this script."
done
WORKTREE_STATUS=$(git status --porcelain --untracked-files=all)
[ -z "$WORKTREE_STATUS" ] ||
    die "Commit or stash all changes, including untracked files, first."
git var GIT_COMMITTER_IDENT > /dev/null

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
    die "Could not fetch $SOURCE_REMOTE/$SOURCE_BRANCH; no changes imported."
SOURCE_HEAD=$(git rev-parse --verify "$REMOTE_REF^{commit}")

BASE=$(git merge-base --all "$START_HEAD" "$SOURCE_HEAD") ||
    die "The branches have no common ancestor."
[[ "$BASE" != *$'\n'* ]] || die "The branches have multiple merge bases."
if git diff --quiet "$BASE" "$SOURCE_HEAD"; then
    die "The source has no changes to import; keeping both branches."
fi

# Create an unattached commit with the fetched tree and the common ancestor
# as its only parent. Cherry-picking it applies the complete branch delta,
# including merge commits, without rewriting either branch's history.
SQUASHED_COMMIT=$(
    {
        printf 'Squash branch %s\n\n' "$SOURCE_BRANCH"
        git log --reverse --format='%h %s%n%b' "$BASE..$SOURCE_HEAD"
    } | git commit-tree "$SOURCE_HEAD^{tree}" -p "$BASE"
)
if ! git cherry-pick --no-commit "$SQUASHED_COMMIT"; then
    echo "The import failed; both source branches have been kept." >&2
    echo "Resolve and commit manually, or discard this import with:" >&2
    echo "  git reset --merge $START_HEAD" >&2
    exit 1
fi
if git diff --cached --quiet; then
    die "The changes are already present; keeping both source branches."
fi
git commit --reset-author -C "$SQUASHED_COMMIT" ||
    die "Commit failed; the import remains staged and both source branches are kept."

echo "Imported $SOURCE_REMOTE/$SOURCE_BRANCH onto $CURRENT_BRANCH as one commit; source branches kept."
