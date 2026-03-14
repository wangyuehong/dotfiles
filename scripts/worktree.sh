#!/bin/bash -e

if [[ -z "$1" ]]; then
  echo "Usage: worktree.sh <repo-url> [branch]" >&2
  exit 1
fi

repo="$1"
dir="${repo##*/}"
dir="${dir%.*}"
echo "$dir"
branch="$2"
defaultBranch="${branch:-main}"

mkdir -p "$dir"
cd "$dir"

git clone --bare "$repo" .bare
echo "gitdir: ./.bare" > .git
echo "fetch = +refs/heads/*:refs/remotes/origin/*" >> ./.bare/config

git worktree add "$defaultBranch"
