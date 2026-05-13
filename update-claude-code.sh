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

# ── Helper: restart a macOS app by name if it is currently running ─────────
restart_app_if_running() {
    local app_name="$1"   # e.g. "Claude"
    if pgrep -x "$app_name" > /dev/null 2>&1; then
        echo "$(date): [$app_name] is running — restarting..." >> "$LOG"
        osascript -e "tell application \"$app_name\" to quit"
        sleep 2
        open -a "$app_name"
        echo "$(date): [$app_name] restarted." >> "$LOG"
    else
        echo "$(date): [$app_name] was not running — skipping restart." >> "$LOG"
    fi
}

# ── Helper: upgrade one package, notify and optionally restart app ──────────
upgrade_and_notify() {
    local pkg="$1"        # brew package name
    local label="$2"      # human-readable name for the notification
    local extra_flag="$3" # e.g. "--cask" for desktop apps, "" for formulae
    local app_name="$4"   # macOS app name to restart if updated (optional)

    local before after
    before=$("$BREW" list $extra_flag --versions "$pkg" 2>/dev/null | awk '{print $2}')

    echo "$(date): [$label] current version: ${before:-not installed}" >> "$LOG"

    "$BREW" upgrade $extra_flag "$pkg" >> "$LOG" 2>&1

    after=$("$BREW" list $extra_flag --versions "$pkg" 2>/dev/null | awk '{print $2}')

    if [[ "$before" != "$after" && -n "$after" ]]; then
        local msg="Updated: ${before:-?} → $after"
        echo "$(date): [$label] $msg" >> "$LOG"
        notify "$label Updated ✅" "$msg"
        # Restart the app if one was specified
        if [[ -n "$app_name" ]]; then
            restart_app_if_running "$app_name"
        fi
    else
        echo "$(date): [$label] Already up to date (${after:-unknown})." >> "$LOG"
    fi
}

# ── Claude Code (CLI formula) — no app to restart ─────────────────────────
upgrade_and_notify "claude-code" "Claude Code" "" ""

# ── Claude Desktop (cask) — restart Claude app if updated ─────────────────
upgrade_and_notify "claude" "Claude Desktop" "--cask" "Claude"

echo "$(date): ── Done ──" >> "$LOG"
