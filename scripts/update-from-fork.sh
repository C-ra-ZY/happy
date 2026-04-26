#!/usr/bin/env bash
# Force-update happy from this fork after an upstream rebase / history rewrite.
#
# When you rebase the fork branch on the dev machine and force-push, deployment
# machines can't fast-forward. This script discards local changes in
# $HAPPY_INSTALL_DIR, hard-resets to origin/$HAPPY_FORK_BRANCH, and re-runs
# install-from-fork.sh.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/update-from-fork.sh | bash
#   # or after install-from-fork.sh ran at least once:
#   bash $HOME/code/happy/scripts/update-from-fork.sh
#
# Env:
#   HAPPY_INSTALL_DIR     where the fork is checked out (default: $HOME/code/happy)
#   HAPPY_FORK_BRANCH     branch to sync to (default: local-fix-pr570)
#   HAPPY_DISCARD_LOCAL=1 also discard uncommitted edits (otherwise abort if dirty)

set -euo pipefail

BRANCH="${HAPPY_FORK_BRANCH:-local-fix-pr570}"
INSTALL_DIR="${HAPPY_INSTALL_DIR:-$HOME/code/happy}"

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    err "$INSTALL_DIR is not a git checkout. Run install-from-fork.sh first."
    exit 1
fi

cd "$INSTALL_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    err "Working tree at $INSTALL_DIR has local changes:"
    git status --short >&2
    if [[ "${HAPPY_DISCARD_LOCAL:-0}" != "1" ]]; then
        err "Commit/stash them, or set HAPPY_DISCARD_LOCAL=1 to drop them."
        exit 1
    fi
    warn "HAPPY_DISCARD_LOCAL=1 — discarding local changes"
fi

step "Force-syncing $INSTALL_DIR → origin/$BRANCH"
git fetch origin --quiet
# Create local branch from origin if it doesn't exist
git checkout "$BRANCH" 2>/dev/null || git checkout -B "$BRANCH" "origin/$BRANCH"
git reset --hard "origin/$BRANCH"

INSTALLER="$INSTALL_DIR/scripts/install-from-fork.sh"
if [[ ! -x "$INSTALLER" ]]; then
    err "$INSTALLER missing or not executable after sync."
    err "The fork may not contain the install script anymore — check $BRANCH on origin."
    exit 1
fi

step "Handing off to install-from-fork.sh"
exec bash "$INSTALLER"
