#!/usr/bin/env bash
# tmux-im-sync.sh: Sync input method color to tmux pane border
# Features:
#   - sourceID → color mapping
#   - Dedup: skip if color unchanged
#   - Lock: prevent concurrent execution
set -euo pipefail

DEFAULT_COLOR="brightmagenta"
LOCK_TIMEOUT_SEC=4

CACHE_DIR="${HOME}/.cache/tmux-im-color"
LOCK_DIR="${CACHE_DIR}/lock"

# Map source_id to color
get_im_color() {
	local source_id="$1"
	case "$source_id" in
		im.rime.inputmethod.Squirrel.Hans) echo "#E53935" ;;   # Rime 中文 → 红
		com.google.inputmethod.Japanese.*) echo "#2C78BF" ;;   # Google 日文 → 蓝
		*) echo "" ;;                                          # 其他 → 空 (使用默认)
	esac
}

# Acquire lock with stale lock detection
acquire_lock() {
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		date +%s > "$LOCK_DIR/ts"
		return 0
	fi

	local lock_time now
	lock_time=$(cat "$LOCK_DIR/ts" 2>/dev/null || echo 0)
	case $lock_time in (*[!0-9]*|'') lock_time=0 ;; esac
	now=$(date +%s)

	if [[ $((now - lock_time)) -lt $LOCK_TIMEOUT_SEC ]]; then
		return 1
	fi

	rm -rf "$LOCK_DIR"
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		date +%s > "$LOCK_DIR/ts"
		return 0
	fi
	return 1
}

main() {
	[[ $# -lt 1 ]] && exit 1
	local source_id="$1"

	tmux has-session 2>/dev/null || exit 0
	mkdir -p "$CACHE_DIR"

	acquire_lock || exit 0
	trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM HUP

	local color target_style
	color=$(get_im_color "$source_id")
	if [[ -n "$color" ]]; then
		target_style="fg=$color"
	else
		target_style="fg=$DEFAULT_COLOR"
	fi

	# Dedup: skip if color unchanged
	local current_color
	current_color=$(tmux show-options -gqv @im-color 2>/dev/null || echo "")
	[[ "$current_color" == "$color" ]] && exit 0

	tmux set-option -g @im-color "$color"
	tmux set-option -g pane-active-border-style "$target_style"
	tmux refresh-client -S
}

main "$@"
