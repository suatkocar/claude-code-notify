#!/bin/bash
# Claude Code Notify - Installation Script
# macOS native notifications for Claude Code

set -e

echo "Installing Claude Code Notify..."

# Create directories
mkdir -p ~/.claude/ClaudeNotify.app/Contents/MacOS
mkdir -p ~/.claude/ClaudeNotify.app/Contents/Resources

# Compile Swift app
echo "Compiling notification app..."
swiftc -o ~/.claude/ClaudeNotify.app/Contents/MacOS/ClaudeNotify \
    "$(dirname "$0")/src/ClaudeNotify.swift" \
    -framework UserNotifications \
    -framework AppKit

# Create Info.plist
cat > ~/.claude/ClaudeNotify.app/Contents/Info.plist << 'EOF'
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

# Copy icon from Claude Desktop if available
if [[ -f "/Applications/Claude.app/Contents/Resources/electron.icns" ]]; then
    echo "Copying Claude icon..."
    cp "/Applications/Claude.app/Contents/Resources/electron.icns" \
       ~/.claude/ClaudeNotify.app/Contents/Resources/AppIcon.icns
fi

# Sign the app
echo "Signing app..."
codesign --force --deep --sign - ~/.claude/ClaudeNotify.app

# Copy notify script
cp "$(dirname "$0")/scripts/notify.sh" ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh

# Run once to request notification permission
echo "Requesting notification permission..."
open -g -a ~/.claude/ClaudeNotify.app --args -t "Claude Code" -m "Notifications enabled!" -s "Glass"

echo ""
echo "Installation complete!"
echo ""
echo "Add the following hooks to your ~/.claude/settings.json:"
echo ""
cat << 'HOOKS'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/notify.sh 'Claude Code' 'Task completed' 'Glass' \"$TERM_PROGRAM\""
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
            "command": "~/.claude/notify.sh 'Claude Code' 'Waiting for your input' 'Glass' \"$TERM_PROGRAM\""
          }
        ]
      }
    ]
  }
}
HOOKS
