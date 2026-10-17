#!/bin/bash
# Usage: dev-scripts/squash-cherry-pick.sh [--delete-branches] BRANCH
#
# Fetch BRANCH from origin, squash its changes since the common ancestor,
# and cherry-pick them as one commit onto the current branch. The new commit
# uses the current Git committer as its author. Source branches are kept by
# default. Pass --delete-branches to delete BRANCH from origin and locally
# (if it exists) after a successful import. The current branch is not pushed.
# Requires a clean working tree. On conflicts, source branches are kept.
set -euo pipefail

die() {
    echo "Error: $*" >&2
    exit 1
}

USAGE="Usage: $0 [--delete-branches] BRANCH (the branch name on origin, without origin/)"
DELETE_BRANCHES=0
SOURCE_BRANCH=
for argument in "$@"; do
    case "$argument" in
        --delete-branches) DELETE_BRANCHES=1 ;;
        -*) die "Unknown option: $argument. $USAGE" ;;
        *)
            if [ -n "$SOURCE_BRANCH" ] || [ -z "$argument" ]; then
                die "$USAGE"
            fi
            SOURCE_BRANCH=$argument
            ;;
    esac
done
[ -n "$SOURCE_BRANCH" ] || die "$USAGE"
SOURCE_REF="refs/heads/$SOURCE_BRANCH"
REMOTE_REF="refs/remotes/origin/$SOURCE_BRANCH"
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

# A squash does not preserve ancestry, so deletion will need -D. Refuse to
# remove a branch checked out elsewhere or containing unimported local work.
if [ "$DELETE_BRANCHES" -eq 1 ]; then
    while IFS= read -r line; do
        [ "$line" != "branch $SOURCE_REF" ] ||
            die "The source branch is checked out in another worktree."
    done < <(git worktree list --porcelain)
fi

git fetch --no-tags --no-recurse-submodules origin "+$SOURCE_REF:$REMOTE_REF"
SOURCE_HEAD=$(git rev-parse --verify "$REMOTE_REF^{commit}")
LOCAL_HEAD=$(git rev-parse --verify "$SOURCE_REF" 2>/dev/null || true)
if [ "$DELETE_BRANCHES" -eq 1 ] && [ -n "$LOCAL_HEAD" ]; then
    git merge-base --is-ancestor "$LOCAL_HEAD" "$SOURCE_HEAD" ||
        die "Local $SOURCE_BRANCH contains commits absent from origin; keeping both branches."
fi

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

if [ "$DELETE_BRANCHES" -eq 0 ]; then
    echo "Imported $SOURCE_BRANCH onto $CURRENT_BRANCH as one commit; source branches kept."
    exit 0
fi

# Keep the local branch if remote deletion fails. The lease prevents deleting
# commits pushed by someone else since the fetch, even after a force-push.
if [ "$(git rev-parse --verify "$SOURCE_REF" 2>/dev/null || true)" != "$LOCAL_HEAD" ]; then
    die "Import committed, but local $SOURCE_BRANCH changed; skipping branch deletion."
fi
if ! git push --no-follow-tags --recurse-submodules=no \
    --force-with-lease="$SOURCE_REF:$SOURCE_HEAD" origin ":$SOURCE_REF"; then
    die "Import committed on $CURRENT_BRANCH, but remote deletion failed; local source branch kept."
fi
if [ -n "$LOCAL_HEAD" ]; then
    [ "$(git rev-parse --verify "$SOURCE_REF" 2>/dev/null || true)" = "$LOCAL_HEAD" ] ||
        die "Import committed and remote branch deleted, but local branch changed; keeping it."
    git branch -D -- "$SOURCE_BRANCH" ||
        die "Import committed and remote branch deleted, but local branch deletion failed."
fi
echo "Imported $SOURCE_BRANCH onto $CURRENT_BRANCH as one commit and deleted the source branches."
