#!/usr/bin/env bash
# Uninstall the fork and revert to the official happy from npm.
#
# Steps:
#   1. Stop the daemon (best-effort)
#   2. npm unlink -g happy    (drops the workspace symlink, if any)
#   3. npm i -g happy@latest  (installs official happy from npm)
#   4. Restart daemon (so the official version takes over immediately)
#   5. Verify
#
# Note: this does NOT delete the fork checkout at $HAPPY_INSTALL_DIR
# (default: $HOME/code/happy) or your user data at ~/.happy. Delete those
# manually if you want a fully clean state — but be aware that ~/.happy
# holds auth + session history.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/uninstall-from-fork.sh | bash
#   # or:
#   bash $HOME/code/happy/scripts/uninstall-from-fork.sh
#
# Env:
#   HAPPY_INSTALL_DIR  fork checkout dir (default: $HOME/code/happy) — only used in output

set -euo pipefail

INSTALL_DIR="${HAPPY_INSTALL_DIR:-$HOME/code/happy}"

# Same PATH augmentation as install: ensure post-revert daemon finds agent CLIs
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.local/share/pnpm:$HOME/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:$PATH"

step() { printf '\n\033[1m▶ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }

command -v npm >/dev/null || { err "missing prerequisite: npm"; exit 1; }

# 1. Stop daemon (best-effort — may be running under either fork or official happy)
if command -v happy >/dev/null; then
    step "Stopping daemon"
    happy daemon stop || warn "daemon stop failed (probably wasn't running)"
fi

# 2. Drop the workspace symlink (idempotent)
step "npm unlink -g happy"
npm unlink -g happy 2>/dev/null || warn "no global symlink for happy (already unlinked or never linked)"

# 3. Install the official happy from npm registry
step "npm i -g happy@latest"
npm i -g happy@latest

# 4. Start daemon with the official binary
if command -v happy >/dev/null; then
    step "Starting daemon"
    happy daemon start
else
    warn "happy not on PATH after install — npm's global bin dir may not be in PATH."
    warn "Run \`npm config get prefix\` to find it; add \$prefix/bin to your shell rc."
fi

echo
step "Verification"
printf '  which happy → %s\n' "$(command -v happy || echo 'NOT FOUND')"
if command -v happy >/dev/null; then
    happy --version 2>/dev/null || true
fi

echo
echo "Reverted to official happy."
echo "  Fork checkout: $INSTALL_DIR (intact — delete manually if you want)"
echo "  User data:     ~/.happy   (intact — holds auth/sessions; delete only for full reset)"
echo
echo "To re-install the fork:"
echo "  curl -fsSL https://raw.githubusercontent.com/C-ra-ZY/happy/local-fix-pr570/scripts/install-from-fork.sh | bash"
