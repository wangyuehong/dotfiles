#!/usr/bin/env bash
# tmux-im.sh: Input method manager for tmux panes
#
# Pane options used:
#   @im       - Saved input method state
#   @im-saved - Protection flag (1 = skip sync save during prefix/copy-mode)
#   @im-color - Border color for tmux format #{@im-color}
#
# Called by:
#   - tmux hooks (focus-in, mode-changed, prefix)
#   - Hammerspoon (sync) when input method changes in terminal
#
# Hammerspoon is single-threaded and uses hs.execute() synchronously,
# so concurrent calls are not possible. No locking needed.
set -euo pipefail

DEFAULT_IM="${TMUX_IM_DEFAULT:-com.apple.keylayout.ABC}"
LOG_FILE="${HOME}/.cache/tmux-im/debug.log"

_init_log() {
	mkdir -p "$(dirname "$LOG_FILE")"
	# Use gdate for microsecond precision if available
	if command -v gdate &>/dev/null; then
		_timestamp() { gdate '+%Y-%m-%d %H:%M:%S.%6N'; }
	else
		_timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
	fi
	log() {
		echo "[$(_timestamp)] $*" >> "$LOG_FILE"
	}
}
_init_log

get_current_im() {
	local im
	im=$(macism)
	log "get_current_im: $im"
	echo "$im"
}

switch_im() {
	local target="$1"
	local current
	current=$(get_current_im)
	log "switch_im: current=$current target=$target"
	# Skip if already using target IM to avoid unnecessary switch
	if [[ "$current" != "$target" ]]; then
		log "switch_im: switching to $target"
		macism "$target"
	else
		log "switch_im: already at target, skipping"
	fi
	return 0
}

save_im() {
	local pane_id="$1"
	local current_im="${2:-$(get_current_im)}"
	log "save_im: pane_id=$pane_id current_im=$current_im"
	tmux set-option -p -t "$pane_id" @im "$current_im"
}

restore_im() {
	local pane_id="$1"
	local target_im
	target_im=$(tmux show-options -pqv -t "$pane_id" @im)
	if [[ -z "$target_im" ]]; then
		target_im="$DEFAULT_IM"
	fi
	log "restore_im: pane_id=$pane_id target_im=$target_im"
	switch_im "$target_im"
}

# Update border color for a pane based on IM
# Uses pane option @im-color so tmux format #{@im-color} reads active pane's value
# This enables instant color update on pane switch without waiting for hooks
update_border_color() {
	local pane_id="$1"
	local source_id="$2"

	local color
	color=$(get_im_color "$source_id")

	# Dedup: skip if unchanged
	local current_color
	current_color=$(tmux show-options -pqv -t "$pane_id" @im-color 2>/dev/null || echo "")
	[[ "$current_color" == "$color" ]] && return

	log "update_border_color: pane=$pane_id color=${color:-default}"
	tmux set-option -p -t "$pane_id" @im-color "$color"
	tmux refresh-client -S
}

# Map source_id to color
get_im_color() {
	local source_id="$1"
	case "$source_id" in
		im.rime.inputmethod.Squirrel.Hans) echo "#E53935" ;;   # Rime 中文 → 红
		com.google.inputmethod.Japanese.*) echo "#2C78BF" ;;   # Google 日文 → 蓝
		*) echo "" ;;                                          # 其他 → 空 (使用默认)
	esac
}

# Hook handlers called by tmux set-hook

cmd_focus_in() {
	local pane_id="$1"
	log "cmd_focus_in: pane_id=$pane_id"
	# Clear stale @im-saved flag (may remain from prefix + other command)
	tmux set-option -pu -t "$pane_id" @im-saved 2>/dev/null || true
	# Get target IM and update border color (pane option enables instant display)
	local target_im
	target_im=$(tmux show-options -pqv -t "$pane_id" @im)
	[[ -z "$target_im" ]] && target_im="$DEFAULT_IM"
	update_border_color "$pane_id" "$target_im"
	# Restore IM (slow macism call)
	restore_im "$pane_id"
}

cmd_mode_changed() {
	local pane_id="$1" mode="${2:-}"
	log "cmd_mode_changed: pane_id=$pane_id mode=$mode"

	if [[ -n "$mode" ]]; then
		# Entering copy-mode
		# Check if C-a was just pressed
		local im_saved
		im_saved=$(tmux show-options -pqv -t "$pane_id" @im-saved)
		if [[ "$im_saved" == "1" ]]; then
			# C-a already saved IM and switched to English, skip
			# Keep @im-saved=1 so Hammerspoon callback (after 0.15s debounce) won't overwrite @im
			# It will be cleared when exiting copy-mode or on next focus-in
			log "cmd_mode_changed: entering copy-mode, skipping (already handled by prefix)"
			return 0
		fi
		# Mouse scroll or other way to enter copy-mode
		local current_im
		current_im=$(get_current_im)
		log "cmd_mode_changed: entering copy-mode, saving and switching"
		save_im "$pane_id" "$current_im"
		# Set @im-saved so sync won't overwrite when macism triggers Hammerspoon
		tmux set-option -p -t "$pane_id" @im-saved 1
		if [[ "$current_im" != "$DEFAULT_IM" ]]; then
			log "cmd_mode_changed: switching to $DEFAULT_IM"
			macism "$DEFAULT_IM"
		fi
	else
		# Exiting copy-mode
		log "cmd_mode_changed: exiting copy-mode"
		# Clear @im-saved flag before restoring
		tmux set-option -pu -t "$pane_id" @im-saved 2>/dev/null || true
		# Get target IM and update border color (pane option enables instant display)
		local target_im
		target_im=$(tmux show-options -pqv -t "$pane_id" @im)
		[[ -z "$target_im" ]] && target_im="$DEFAULT_IM"
		update_border_color "$pane_id" "$target_im"
		# Restore IM (slow macism call)
		restore_im "$pane_id"
	fi
}

# Called by C-a binding before entering prefix mode
# Saves IM and switches to English for command input
# Sets @im-saved pane option so mode-changed knows to skip saving
cmd_prefix() {
	local pane_id="$1"
	log "cmd_prefix: pane_id=$pane_id"

	# Get current IM once, use for both save and switch check
	local current_im
	current_im=$(get_current_im)
	save_im "$pane_id" "$current_im"

	# Set pane option so mode-changed will skip saving
	tmux set-option -p -t "$pane_id" @im-saved 1

	# Switch to English if needed
	if [[ "$current_im" != "$DEFAULT_IM" ]]; then
		log "cmd_prefix: switching to $DEFAULT_IM"
		macism "$DEFAULT_IM"
	else
		log "cmd_prefix: already at default, skipping switch"
	fi
}

# Called by Hammerspoon when input method changes in terminal
# Saves IM to active pane (if @im-saved not set) and updates border color
cmd_sync() {
	local source_id="$1"
	log "cmd_sync: source_id=$source_id"

	tmux has-session 2>/dev/null || exit 0

	# Get current session and pane from last active client
	local session_id pane_id
	read -r session_id pane_id < <(tmux display-message -p '#{session_id} #{pane_id}' 2>/dev/null) || true
	[[ -z "$session_id" ]] && exit 0

	# Check @im-saved flag: if set, skip saving @im (prefix/copy-mode already saved)
	# Do NOT clear @im-saved here - user may still be in prefix mode waiting to press Esc
	# @im-saved is cleared by: focus-in (pane switch) or mode-changed (exit copy-mode)
	if [[ -n "$pane_id" ]]; then
		local im_saved
		im_saved=$(tmux show-options -pqv -t "$pane_id" @im-saved 2>/dev/null || echo "")
		if [[ "$im_saved" == "1" ]]; then
			log "cmd_sync: @im-saved=1, skipping save"
		else
			log "cmd_sync: saving @im=$source_id to pane $pane_id"
			tmux set-option -p -t "$pane_id" @im "$source_id"
		fi
		# Update border color (pane option for instant display on pane switch)
		update_border_color "$pane_id" "$source_id"
	fi
}

usage() {
	cat <<EOF
tmux-im.sh - Input method manager for tmux panes

Usage:
  tmux-im.sh focus-in <pane_id>
  tmux-im.sh mode-changed <pane_id> [mode]
  tmux-im.sh prefix <pane_id>
  tmux-im.sh sync <source_id>

Commands:
  focus-in      Restore IM when pane gains focus (tmux hook)
  mode-changed  Handle copy-mode enter/exit (tmux hook)
  prefix        Save IM and switch to English before prefix mode (tmux hook)
  sync          Sync IM state and border color (Hammerspoon)

Environment:
  TMUX_IM_DEFAULT  Default IM (default: com.apple.keylayout.ABC)

Debug:
  Log file: ~/.cache/tmux-im/debug.log
EOF
}

main() {
	[[ $# -eq 0 ]] && { usage; exit 0; }

	local cmd="$1"
	shift

	case "$cmd" in
		focus-in)
			[[ $# -lt 1 ]] && { echo "error: focus-in requires <pane_id>" >&2; exit 1; }
			cmd_focus_in "$1"
			;;
		mode-changed)
			[[ $# -lt 1 ]] && { echo "error: mode-changed requires <pane_id>" >&2; exit 1; }
			cmd_mode_changed "$1" "${2:-}"
			;;
		prefix)
			[[ $# -lt 1 ]] && { echo "error: prefix requires <pane_id>" >&2; exit 1; }
			cmd_prefix "$1"
			;;
		sync)
			[[ $# -lt 1 ]] && { echo "error: sync requires <source_id>" >&2; exit 1; }
			cmd_sync "$1"
			;;
		-h|--help|help)
			usage
			;;
		*)
			echo "error: unknown command: $cmd" >&2
			usage >&2
			exit 1
			;;
	esac
}

main "$@"
