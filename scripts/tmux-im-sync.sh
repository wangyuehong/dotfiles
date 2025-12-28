#!/usr/bin/env bash
# tmux-im-sync.sh: Sync input method color to tmux global option
set -euo pipefail

# Map source_id to color
get_im_color() {
	local source_id="$1"
	case "$source_id" in
		im.rime.inputmethod.Squirrel.Hans) echo "#E53935" ;;   # Rime 中文 → 红
		com.google.inputmethod.Japanese.*) echo "#2C78BF" ;;   # Google 日文 → 蓝
		*) echo "" ;;                                          # 其他 → 空 (使用默认)
	esac
}

main() {
	[[ $# -lt 1 ]] && exit 1

	local source_id="$1"

	# Check if tmux server is running
	tmux has-session 2>/dev/null || exit 0

	local color
	color=$(get_im_color "$source_id")

	# Dedup: skip if unchanged
	local current
	current=$(tmux show-options -gqv @im-color 2>/dev/null || echo "")
	[[ "$current" == "$color" ]] && exit 0

	# Update tmux global option and trigger refresh
	tmux set-option -g @im-color "$color"
	tmux refresh-client -S
}

main "$@"
