#!/bin/bash
# Claude Code Notify - One-line installer
# Usage: curl -fsSL https://raw.githubusercontent.com/suatkocar/claude-code-notify/main/install.sh | bash

set -e

REPO_URL="https://github.com/suatkocar/claude-code-notify"
TEMP_DIR=$(mktemp -d)
CLAUDE_DIR="$HOME/.claude"

echo "╔═══════════════════════════════════════════╗"
echo "║   Claude Code Notify - Installer          ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Check for Xcode Command Line Tools
if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools required"
    echo "Run: xcode-select --install"
    exit 1
fi

# Clone repo to temp directory
echo "[1/5] Downloading..."
git clone --quiet --depth 1 "$REPO_URL" "$TEMP_DIR"

# Create directories
echo "[2/5] Creating app bundle..."
mkdir -p "$CLAUDE_DIR/ClaudeNotify.app/Contents/MacOS"
mkdir -p "$CLAUDE_DIR/ClaudeNotify.app/Contents/Resources"

# Compile Swift app
echo "[3/5] Compiling..."
swiftc -o "$CLAUDE_DIR/ClaudeNotify.app/Contents/MacOS/ClaudeNotify" \
    "$TEMP_DIR/src/ClaudeNotify.swift" \
    -framework UserNotifications \
    -framework AppKit

# Create Info.plist
cat > "$CLAUDE_DIR/ClaudeNotify.app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeNotify</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.claude.notify</string>
    <key>CFBundleName</key>
    <string>Claude Code</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
EOF

# Copy icon (bundled in repo, fallback to Claude Desktop)
if [[ -f "$TEMP_DIR/assets/AppIcon.icns" ]]; then
    cp "$TEMP_DIR/assets/AppIcon.icns" \
       "$CLAUDE_DIR/ClaudeNotify.app/Contents/Resources/AppIcon.icns"
elif [[ -f "/Applications/Claude.app/Contents/Resources/electron.icns" ]]; then
    cp "/Applications/Claude.app/Contents/Resources/electron.icns" \
       "$CLAUDE_DIR/ClaudeNotify.app/Contents/Resources/AppIcon.icns"
fi

# Sign the app
codesign --force --deep --sign - "$CLAUDE_DIR/ClaudeNotify.app" 2>/dev/null

# Copy notify script
cp "$TEMP_DIR/scripts/notify.sh" "$CLAUDE_DIR/notify.sh"
chmod +x "$CLAUDE_DIR/notify.sh"

# Configure hooks in settings.json
echo "[4/5] Configuring hooks..."
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Create settings.json if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Check if jq is available
if command -v jq &>/dev/null; then
    # Check for existing hooks
    if jq -e '.hooks.Stop or .hooks.Notification' "$SETTINGS_FILE" &>/dev/null; then
        echo "    Warning: Existing hooks found. Merging..."
    fi

    # Use jq to merge hooks
    HOOKS='{
      "hooks": {
        "Stop": [
          {
            "matcher": "",
            "hooks": [
              {
                "type": "command",
                "command": "~/.claude/notify.sh '\''Claude Code'\'' '\''Task completed'\'' '\''Glass'\''"
              }
            ]
          }
        ],
        "Notification": [
          {
            "matcher": "permission_prompt",
            "hooks": [
              {
                "type": "command",
                "command": "~/.claude/notify.sh '\''Claude Code'\'' '\''Waiting for your input'\'' '\''Glass'\''"
              }
            ]
          }
        ]
      }
    }'

    # Merge with existing settings
    jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$HOOKS") > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    echo "    Hooks added to settings.json"
else
    # No jq - show manual instructions
    echo ""
    echo "    Note: jq not found. Please add hooks manually to $SETTINGS_FILE"
    echo "    See: $REPO_URL#configuration"
fi

# Cleanup
rm -rf "$TEMP_DIR"

# Request notification permission
echo "[5/5] Requesting notification permission..."
open -g -a "$CLAUDE_DIR/ClaudeNotify.app" --args -t "Claude Code" -m "Notifications enabled!" -s "Glass"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   Installation complete!                  ║"
echo "╚═══════════════════════════════════════════╝"
echo ""
echo "You'll get notifications when:"
echo "  • Claude completes a task"
echo "  • Claude needs permission for a command"
echo ""
echo "Tip: If using Warp, notifications show which tab they came from!"
echo ""
