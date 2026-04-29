#!/bin/bash
# install-claude-updater.sh
# One-shot installer: deploys the Claude auto-updater script and LaunchAgent.
# Run once with: bash install-claude-updater.sh

set -e

# ── Colours ───────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  ✔ $*${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ $*${NC}"; }
fail() { echo -e "${RED}  ✘ $*${NC}"; exit 1; }
step() { echo -e "\n${YELLOW}▸ $*${NC}"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Claude Auto-Updater Installer      ║"
echo "╚══════════════════════════════════════════╝"

# ── 1. Check Homebrew ─────────────────────────────────────────────────────
step "Checking Homebrew..."
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    BREW="/opt/homebrew/bin/brew"
elif [[ -x "/usr/local/bin/brew" ]]; then
    BREW="/usr/local/bin/brew"
else
    fail "Homebrew not found. Install it first: https://brew.sh"
fi
ok "Homebrew found at $BREW"

# ── 2. Check that claude-code and claude casks are installed ──────────────
step "Checking Claude packages..."

if "$BREW" list --versions claude-code &>/dev/null; then
    ok "claude-code (CLI) is installed"
else
    warn "claude-code not installed — installing now..."
    "$BREW" install claude-code
    ok "claude-code installed"
fi

if "$BREW" list --cask --versions claude &>/dev/null; then
    ok "claude (Desktop) is installed"
else
    warn "Claude Desktop cask not installed — installing now..."
    "$BREW" install --cask claude
    ok "Claude Desktop installed"
fi

# ── 3. Write the updater script ───────────────────────────────────────────
step "Installing updater script to /usr/local/bin/update-claude.sh..."

sudo tee /usr/local/bin/update-claude.sh > /dev/null << 'UPDATER'
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
UPDATER

sudo chmod +x /usr/local/bin/update-claude.sh
ok "Updater script installed"

# ── 4. Write the LaunchAgent plist ────────────────────────────────────────
step "Installing LaunchAgent..."

PLIST="$HOME/Library/LaunchAgents/local.update-claude.plist"

cat > "$PLIST" << 'PLIST_CONTENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>local.update-claude</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/usr/local/bin/update-claude.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/update-claude.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/update-claude.stderr.log</string>
</dict>
</plist>
PLIST_CONTENT

ok "LaunchAgent plist written to $PLIST"

# ── 5. Load (or reload) the LaunchAgent ───────────────────────────────────
step "Loading LaunchAgent..."

# Unload first in case it was previously installed (suppress errors)
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
ok "LaunchAgent loaded — will run on every login"

# ── 6. Run once right now so you see it working immediately ───────────────
step "Running updater now (first test run)..."
bash /usr/local/bin/update-claude.sh
ok "First run complete — check ~/.claude-update.log for details"

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗"
echo    "║         Installation complete! 🎉        ║"
echo    "╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  • Updater script : /usr/local/bin/update-claude.sh"
echo "  • LaunchAgent    : ~/Library/LaunchAgents/local.update-claude.plist"
echo "  • Log file       : ~/.claude-update.log"
echo ""
echo "  Claude Code and Claude Desktop will be checked for updates"
echo "  on every login. You'll get a notification if anything updates."
echo ""
