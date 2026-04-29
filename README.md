# Claude Auto-Updater

Automatically keeps **Claude Code** (CLI) and **Claude Desktop** (macOS app) up to date using Homebrew — triggered silently on every login, with a native macOS notification whenever a new version is actually installed.

---

## How it works

### The problem it solves

Homebrew doesn't auto-update installed packages. Without manual intervention, `claude-code` and the Claude Desktop app silently fall behind as new versions ship. This project wires a tiny updater script into macOS's native login system so you never have to think about it.

### The three components

| File | Purpose |
|---|---|
| `install-claude-updater.sh` | One-shot installer — run this once to set everything up |
| `update-claude.sh` | The updater script installed to `/usr/local/bin/` — runs on every login |
| `local.update-claude.plist` | macOS LaunchAgent — tells the OS to run the updater at login |

### What happens at every login

1. **macOS reads `local.update-claude.plist`** from `~/Library/LaunchAgents/` and launches `update-claude.sh` in the background.
2. **The script detects your Homebrew path** automatically — works on both Apple Silicon (`/opt/homebrew`) and Intel Macs (`/usr/local`).
3. **`brew update`** is run once to refresh the list of available formula and cask versions.
4. **Version snapshot (before)** — the current installed version of each package is recorded.
5. **`brew upgrade`** is attempted for:
   - `claude-code` — the Claude Code CLI (formula)
   - `claude` — the Claude Desktop app (cask)
6. **Version snapshot (after)** — the new installed version is recorded.
7. **Comparison** — if the before and after versions differ, a native macOS notification fires with the exact version change, e.g.:
   > **Claude Code Updated ✅**
   > Updated: 1.2.3 → 1.3.0
8. If nothing changed, the run is silent — no notification spam.
9. Everything is appended to `~/.claude-update.log` for a full audit trail.

### Why `RunAtLoad` instead of a cron schedule

`RunAtLoad: true` in the LaunchAgent plist tells macOS to execute the script each time the agent is loaded — which happens once per user login session. This means:
- It runs when you log in after a full shutdown or restart.
- It runs when you log out and back in.
- It does **not** run on wake from sleep (which is intentional — brew updates don't need to happen every time you open your laptop lid).

---

## Requirements

- macOS (tested on Ventura and later)
- [Homebrew](https://brew.sh) installed
- `claude-code` and/or `claude` installed via Homebrew (the installer will install them if missing)

---

## Installation

Run the installer once — it handles everything:

```bash
bash install-claude-updater.sh
```

The installer will:
1. Verify Homebrew is present
2. Install `claude-code` and `claude` via Homebrew if not already installed
3. Write `update-claude.sh` to `/usr/local/bin/` and make it executable
4. Write `local.update-claude.plist` to `~/Library/LaunchAgents/`
5. Load the LaunchAgent immediately (no restart needed)
6. Run the updater once right away so you can see it working

### What gets installed on your system

```
/usr/local/bin/update-claude.sh          ← the updater script
~/Library/LaunchAgents/local.update-claude.plist  ← the login trigger
~/.claude-update.log                     ← created on first run
```

---

## Uninstallation

```bash
# Unload and remove the LaunchAgent
launchctl unload ~/Library/LaunchAgents/local.update-claude.plist
rm ~/Library/LaunchAgents/local.update-claude.plist

# Remove the updater script
sudo rm /usr/local/bin/update-claude.sh

# Optionally remove the log
rm ~/.claude-update.log
```

---

## Checking the log

```bash
cat ~/.claude-update.log
```

Each run appends a timestamped block like:

```
Tue Apr 29 08:00:01 CEST 2026: ── Starting Claude update check ──
Tue Apr 29 08:00:01 CEST 2026: [Claude Code] current version: 1.2.3
Tue Apr 29 08:00:04 CEST 2026: [Claude Code] Updated: 1.2.3 → 1.3.0
Tue Apr 29 08:00:04 CEST 2026: [Claude Desktop] current version: 0.9.1
Tue Apr 29 08:00:06 CEST 2026: [Claude Desktop] Already up to date (0.9.1).
Tue Apr 29 08:00:06 CEST 2026: ── Done ──
```

---

## Troubleshooting

**"brew not found" notification on login**
The script couldn't locate Homebrew. Check that brew is installed at `/opt/homebrew/bin/brew` (Apple Silicon) or `/usr/local/bin/brew` (Intel). Run `which brew` in Terminal to confirm.

**No notification, nothing in the log**
The LaunchAgent may not have loaded. Re-run the installer or manually load it:
```bash
launchctl load ~/Library/LaunchAgents/local.update-claude.plist
```

**"formula not found" error for `claude` or `claude-code`**
Confirm the exact Homebrew names on your system:
```bash
brew search claude
```
If the names differ, edit the two `upgrade_and_notify` calls at the bottom of `/usr/local/bin/update-claude.sh`.
