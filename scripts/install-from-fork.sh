#!/usr/bin/env bash
# Install happy-cli from this fork.
# Idempotent: clones if missing, pulls + rebuilds if present.
#
# Why we augment PATH explicitly:
# The happy daemon uses `command -v claude` (and similar) to report agent
# availability to the mobile app. The daemon inherits PATH from whatever
# spawns it — and on WSL / remote SSH / non-interactive shells, common tool
# dirs like ~/.local/bin can be missing. The daemon then reports "claude
# not detected" on mobile even though `happy claude` works fine from your
# interactive shell. We prepend common locations here so the daemon (and
# all its later self-restarts) keep a sane PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/install-from-fork.sh | bash
#   # or after cloning manually:
#   bash scripts/install-from-fork.sh
#
# Env overrides:
#   HAPPY_FORK_URL    (default: https://github.com/C-ra-ZY/happy.git)
#   HAPPY_FORK_BRANCH (default: local-fix-pr570)
#   HAPPY_INSTALL_DIR (default: $HOME/code/happy)

set -euo pipefail

REPO_URL="${HAPPY_FORK_URL:-https://github.com/C-ra-ZY/happy.git}"
BRANCH="${HAPPY_FORK_BRANCH:-local-fix-pr570}"
INSTALL_DIR="${HAPPY_INSTALL_DIR:-$HOME/code/happy}"

# Prepend common CLI tool dirs so daemon sees them. User's PATH still wins.
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.local/share/pnpm:$HOME/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }

step "Target: $INSTALL_DIR  ($REPO_URL @ $BRANCH)"

for cmd in git node npm; do
    command -v "$cmd" >/dev/null || { err "missing prerequisite: $cmd"; exit 1; }
done

if ! command -v pnpm >/dev/null; then
    step "pnpm not found, enabling via corepack"
    corepack enable
    corepack prepare pnpm@latest --activate
fi

# Pre-flight: warn early if no agent CLI is even on PATH
if ! command -v claude >/dev/null && ! command -v codex >/dev/null; then
    warn "Neither 'claude' nor 'codex' is on PATH (even after augmentation)."
    warn "Install at least one before relying on happy — daemon will report no agents on mobile."
fi

if [[ -d "$INSTALL_DIR/.git" ]]; then
    step "Update existing checkout"
    cd "$INSTALL_DIR"
    git fetch origin --quiet
    git checkout "$BRANCH"
    if ! git pull --ff-only origin "$BRANCH"; then
        err "Cannot fast-forward — the fork branch was likely force-pushed (e.g., rebased onto upstream)."
        err "To force-resync (discards uncommitted changes in $INSTALL_DIR):"
        err "  curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/$BRANCH/scripts/update-from-fork.sh | bash"
        exit 1
    fi
else
    step "Clone fork"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --branch "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

step "pnpm install"
pnpm install

step "Build @slopus/happy-wire (prerequisite on clean checkout)"
pnpm --filter @slopus/happy-wire build

step "cli:install (build + npm link + daemon restart + verify)"
pnpm --filter happy cli:install

# Post-install: print what daemon now sees through its PATH
echo
step "Verification (this is what the daemon now sees)"
printf '  which happy  → %s\n' "$(command -v happy)"
printf '  which claude → %s\n' "$(command -v claude || echo 'NOT FOUND')"
printf '  which codex  → %s\n' "$(command -v codex  || echo 'NOT FOUND')"
printf '  which gemini → %s\n' "$(command -v gemini || echo 'NOT FOUND')"

echo
echo "On the mobile app, this machine should now show the above CLIs as detected."
echo "If something is missing on mobile, restart the daemon from your interactive shell:"
echo "  happy daemon stop && happy daemon start"
echo
echo "To revert to the official happy from npm:"
echo "  curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/uninstall-from-fork.sh | bash"
