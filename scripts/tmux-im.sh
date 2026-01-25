#!/usr/bin/env bash
# tmux-im.sh: Input method border sync for tmux panes
#
# Pane options used:
#   @im-color     - Border color for tmux format #{@im-color}
#
# Called by:
#   - tmux hooks (focus-in, mode-changed, prefix)
#   - Hammerspoon (sync) when input method changes in terminal
#
# Hammerspoon is single-threaded and uses hs.execute() synchronously,
# so concurrent calls are not possible. No locking needed.
set -euo pipefail

DEFAULT_IM="${TMUX_IM_DEFAULT:-com.apple.keylayout.ABC}"
LOG_FILE="${TMUX_IM_LOG:-${HOME}/.cache/tmux-im/debug.log}"

_init_log() {
	mkdir -p "$(dirname "$LOG_FILE")"
	_timestamp() { gdate '+%Y-%m-%d %H:%M:%S.%6N'; }
	log() {
		echo "[$(_timestamp)] $*" >> "$LOG_FILE"
	}
}
_init_log

# Shorten IM ID for logging
short_im() {
	case "$1" in
		im.rime.inputmethod.Squirrel.Hans) echo "Rime" ;;
		com.google.inputmethod.Japanese.*) echo "GoogleJP" ;;
		com.apple.keylayout.ABC) echo "ABC" ;;
		*) echo "$1" ;;
	esac
}

get_current_im() {
	macism
}

# Switch IM, log only when actual switch happens
switch_im() {
	local target="$1"
	local current
	current=$(get_current_im)
	if [[ "$current" == "$target" ]]; then
		return 0
	fi
	log "switch: $(short_im "$current") -> $(short_im "$target")"
	if [[ "$target" == "$DEFAULT_IM" ]]; then
		macism "$target" 0
	else
		macism "$target"
	fi
}

# Switch to English for prefix/copy-mode
# Sets global: SAVED_IM (current IM ID), SWITCHED (1 if switched, 0 otherwise)
save_and_switch_to_english() {
	local pane_id="$1"
	SAVED_IM=$(get_current_im)
	if [[ "$SAVED_IM" != "$DEFAULT_IM" ]]; then
		switch_im "$DEFAULT_IM"
		SWITCHED=1
	else
		SWITCHED=0
	fi
	update_border_color "$pane_id" "$DEFAULT_IM"
}

# Sync pane border to current IM (no switching)
# Sets global: CURRENT_IM for caller logging
sync_pane_border_to_current_im() {
	local pane_id="$1"
	CURRENT_IM=$(get_current_im)
	update_border_color "$pane_id" "$CURRENT_IM"
}

# Update border color, log only when changed
update_border_color() {
	local pane_id="$1"
	local source_id="$2"
	local color
	color=$(get_im_color "$source_id")

	local current_color
	current_color=$(tmux show-options -pqv -t "$pane_id" @im-color 2>/dev/null || echo "")
	if [[ "$current_color" != "$color" ]]; then
		log "border: pane=$pane_id color=${color:-default}"
		tmux set-option -p -t "$pane_id" @im-color "$color"
	fi
	tmux refresh-client -S
}

# Map source_id to color
get_im_color() {
	local source_id="$1"
	case "$source_id" in
		im.rime.inputmethod.Squirrel.Hans) echo "#E53935" ;;   # Rime Chinese -> red
		com.google.inputmethod.Japanese.*) echo "#2C78BF" ;;   # Google Japanese -> blue
		*) echo "" ;;                                          # others -> empty (default)
	esac
}

# tmux hook handlers

cmd_focus_in() {
	local pane_id="$1"

	# Normal focus-in: sync border to current IM
	sync_pane_border_to_current_im "$pane_id"
	log "focus_in: pane=$pane_id | sync border im=$(short_im "$CURRENT_IM")"
}

cmd_mode_changed() {
	local pane_id="$1" mode="${2:-}"

	if [[ -n "$mode" ]]; then
		# Entering copy-mode
		# Mouse scroll or other way to enter copy-mode
		save_and_switch_to_english "$pane_id"
		if [[ $SWITCHED -eq 1 ]]; then
			log "mode_changed: pane=$pane_id | enter $mode | im=$(short_im "$SAVED_IM") | switch to ABC"
		else
			log "mode_changed: pane=$pane_id | enter $mode | im=ABC | no switch"
		fi
	else
		# Exiting copy-mode
		sync_pane_border_to_current_im "$pane_id"
		log "mode_changed: pane=$pane_id | exit copy-mode | sync border im=$(short_im "$CURRENT_IM")"
	fi
}

cmd_prefix() {
	local pane_id="$1"
	save_and_switch_to_english "$pane_id"
	if [[ $SWITCHED -eq 1 ]]; then
		log "prefix: pane=$pane_id | im=$(short_im "$SAVED_IM") | switch to ABC"
	else
		log "prefix: pane=$pane_id | im=ABC | no switch"
	fi
}

# Hammerspoon handler
cmd_sync() {
	local source_id
	source_id=$(get_current_im)

	tmux has-session 2>/dev/null || exit 0

	local pane_id
	pane_id=$(tmux display-message -p '#{pane_id}' 2>/dev/null) || true
	[[ -z "$pane_id" ]] && exit 0

	log "sync: pane=$pane_id | im=$(short_im "$source_id") | border updated"
	update_border_color "$pane_id" "$source_id"
}

usage() {
	cat <<EOF
tmux-im.sh - Input method manager for tmux panes

Usage:
  tmux-im.sh focus-in <pane_id>
  tmux-im.sh mode-changed <pane_id> [mode]
  tmux-im.sh prefix <pane_id>
  tmux-im.sh sync

Commands:
  focus-in      Sync border color when pane gains focus (tmux hook)
  mode-changed  Handle copy-mode enter/exit (tmux hook)
  prefix        Save IM and switch to English before prefix mode (tmux hook)
  sync          Sync current IM and border color (Hammerspoon)

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
			cmd_sync
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

# Allow sourcing without executing main (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
