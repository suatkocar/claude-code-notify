#!/bin/bash
# Claude Code Notification Script
# Gets Warp tab name and sends notification

TITLE="${1:-Claude Code}"
MESSAGE="${2:-Task completed}"
SOUND="${3:-Glass}"
TERMINAL="${4:-}"

# Try to get Warp tab name if running in Warp
TAB_NAME=""
if [[ "$TERMINAL" == "WarpTerminal" ]] || [[ "$TERMINAL" == "Warp" ]]; then
    TAB_NAME=$(osascript -e 'tell application "System Events" to get name of first window of application process "Warp"' 2>/dev/null)
    # Remove the sparkle prefix (✳ ) if present
    if [[ "$TAB_NAME" == "✳ "* ]]; then
        TAB_NAME="${TAB_NAME:2}"
    fi
fi

# Build message with tab name suffix if available
if [[ -n "$TAB_NAME" ]]; then
    FULL_MESSAGE="$MESSAGE - $TAB_NAME"
else
    FULL_MESSAGE="$MESSAGE"
fi

# Send notification
open -g -a ~/.claude/ClaudeNotify.app --args -t "$TITLE" -m "$FULL_MESSAGE" -s "$SOUND"
