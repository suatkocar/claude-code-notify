#!/bin/bash
# Claude Code Notification Script
# Supports two modes:
#   1. Direct args: notify.sh "title" "message" "sound" "terminal"
#   2. Stdin JSON: piped from Stop/Notification hooks (reads last_assistant_message etc.)

# CLAUDE_NOTIFY=off silences notifications anywhere, CLAUDE_NOTIFY=on forces them.
# Unset, they stay quiet inside Ghostex, whose own hook already shows a
# notification and plays a sound for the same events. The check mirrors the one
# in Ghostex's agent-shell-notify.sh, so this goes quiet exactly where Ghostex
# takes over.
stay_quiet() {
    case "${CLAUDE_NOTIFY:-}" in
        off) return 0 ;;
        on) return 1 ;;
    esac
    [[ -n "${GHOSTEX_GLOBAL_SESSION_REF:-}" && -n "${GHOSTEX_GXSERVER_BASE_URL:-}" ]]
}
if stay_quiet; then
    # Drain the hook's JSON; argument calls may have an open stdin that never ends.
    [[ $# -eq 0 && ! -t 0 ]] && cat >/dev/null
    exit 0
fi

# If stdin has data and no args, read from JSON
if [[ $# -eq 0 ]] && ! [[ -t 0 ]]; then
    INPUT=$(cat)
    HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // ""')

    if [[ "$HOOK_EVENT" == "Stop" ]]; then
        # Prevent infinite loops: if a Stop hook is already active, skip
        STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
        if [[ "$STOP_ACTIVE" == "true" ]]; then
            exit 0
        fi
        TITLE="Claude Code"
        # Use last_assistant_message if available (new in ~2.1.69)
        LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' | head -c 80)
        if [[ -n "$LAST_MSG" ]]; then
            MESSAGE="Done: $LAST_MSG"
        else
            MESSAGE="Task completed"
        fi
        SOUND="Glass"

    elif [[ "$HOOK_EVENT" == "Notification" ]]; then
        TITLE=$(echo "$INPUT" | jq -r '.title // "Claude Code"')
        MESSAGE=$(echo "$INPUT" | jq -r '.message // "Notification"')
        SOUND="Glass"

    else
        TITLE="Claude Code"
        MESSAGE="Notification"
        SOUND="Glass"
    fi

    TERMINAL="${TERM_PROGRAM:-}"
else
    TITLE="${1:-Claude Code}"
    MESSAGE="${2:-Task completed}"
    SOUND="${3:-Glass}"
    TERMINAL="${4:-}"
fi

# Try to get Warp tab name if running in Warp
TAB_NAME=""
if [[ "$TERMINAL" == "WarpTerminal" ]] || [[ "$TERMINAL" == "Warp" ]]; then
    TAB_NAME=$(osascript -e 'tell application "System Events" to get name of first window of application process "Warp"' 2>/dev/null)
    # Remove common prefixes: ✳, -, •, etc. (Warp uses different indicators)
    TAB_NAME=$(echo "$TAB_NAME" | sed -E 's/^[✳•\-] //')
fi

# Build message with tab name suffix if available
if [[ -n "$TAB_NAME" ]]; then
    FULL_MESSAGE="$MESSAGE - $TAB_NAME"
else
    FULL_MESSAGE="$MESSAGE"
fi

# Send notification
open -g -a ~/.claude/ClaudeNotify.app --args -t "$TITLE" -m "$FULL_MESSAGE" -s "$SOUND"
