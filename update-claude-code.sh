#!/bin/bash
# update-claude.sh
# Upgrades Claude Code (CLI) and Claude Desktop (cask) via Homebrew at login.
# Sends a macOS notification for each package if its version actually changed.

LOG="$HOME/.claude-update.log"

notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\""
}

# Determine brew path (Apple Silicon vs Intel)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    BREW="/opt/homebrew/bin/brew"
elif [[ -x "/usr/local/bin/brew" ]]; then
    BREW="/usr/local/bin/brew"
else
    echo "$(date): brew not found" >> "$LOG"
    notify "Claude Updater" "❌ brew not found — update skipped."
    exit 1
fi

echo "" >> "$LOG"
echo "$(date): ── Starting Claude update check ──" >> "$LOG"

# Refresh formulae & casks once (shared for both packages)
"$BREW" update --quiet >> "$LOG" 2>&1

# ── Helper: upgrade one package and notify if version changed ──────────────
upgrade_and_notify() {
    local pkg="$1"        # brew package name
    local label="$2"      # human-readable name for the notification
    local extra_flag="$3" # e.g. "--cask" for desktop apps, "" for formulae

    local before after
    before=$("$BREW" list $extra_flag --versions "$pkg" 2>/dev/null | awk '{print $2}')

    echo "$(date): [$label] current version: ${before:-not installed}" >> "$LOG"

    "$BREW" upgrade $extra_flag "$pkg" >> "$LOG" 2>&1

    after=$("$BREW" list $extra_flag --versions "$pkg" 2>/dev/null | awk '{print $2}')

    if [[ "$before" != "$after" && -n "$after" ]]; then
        local msg="Updated: ${before:-?} → $after"
        echo "$(date): [$label] $msg" >> "$LOG"
        notify "$label Updated ✅" "$msg"
    else
        echo "$(date): [$label] Already up to date (${after:-unknown})." >> "$LOG"
    fi
}

# ── Claude Code (CLI formula) ──────────────────────────────────────────────
upgrade_and_notify "claude-code" "Claude Code" ""

# ── Claude Desktop (cask) ─────────────────────────────────────────────────
upgrade_and_notify "claude" "Claude Desktop" "--cask"

echo "$(date): ── Done ──" >> "$LOG"
