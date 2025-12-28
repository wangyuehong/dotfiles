#!/usr/bin/env bash
# tmux-im.sh: Input method manager for tmux panes
# Works with tmux-im (Go storage layer) to save/restore IM per pane
set -euo pipefail

DEFAULT_IM="${TMUX_IM_DEFAULT:-com.apple.keylayout.ABC}"
LOG_FILE="${HOME}/.cache/tmux-im/debug.log"

_log_init=false
log() {
	if [[ "$_log_init" != "true" ]]; then
		mkdir -p "$(dirname "$LOG_FILE")"
		_log_init=true
	fi
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

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
	local pane_key="$1"
	local current_im="${2:-$(get_current_im)}"
	log "save_im: pane_key=$pane_key current_im=$current_im"
	tmux-im "$pane_key" "$current_im"
}

restore_im() {
	local pane_key="$1"
	local target_im
	target_im=$(tmux-im "$pane_key")
	log "restore_im: pane_key=$pane_key target_im=$target_im"
	switch_im "$target_im"
}

# Hook handlers called by tmux set-hook

cmd_focus_out() {
	local session="$1" pane_id="$2"
	local pane_key="${session}:${pane_id}"
	log "cmd_focus_out: pane_key=$pane_key"

	# Check if IM was already saved by cmd_prefix
	# Use -t to target the specific pane (focus may have already changed)
	local im_saved
	im_saved=$(tmux show-options -pqv -t "$pane_id" @im-saved)
	if [[ "$im_saved" == "1" ]]; then
		log "cmd_focus_out: skipping (already saved by prefix)"
		tmux set-option -pu -t "$pane_id" @im-saved
		return 0
	fi
	save_im "$pane_key"
}

cmd_focus_in() {
	local session="$1" pane_id="$2"
	local pane_key="${session}:${pane_id}"
	log "cmd_focus_in: pane_key=$pane_key"
	restore_im "$pane_key"
}

cmd_mode_changed() {
	local session="$1" pane_id="$2" mode="${3:-}"
	local pane_key="${session}:${pane_id}"
	log "cmd_mode_changed: pane_key=$pane_key mode=$mode"

	if [[ -n "$mode" ]]; then
		# Entering copy-mode
		# Check if C-a was just pressed (use -t for consistency)
		local im_saved
		im_saved=$(tmux show-options -pqv -t "$pane_id" @im-saved)
		if [[ "$im_saved" == "1" ]]; then
			# C-a already saved IM and switched to English, skip
			log "cmd_mode_changed: entering copy-mode, skipping (already handled by prefix)"
			tmux set-option -pu -t "$pane_id" @im-saved
			return 0
		fi
		# Mouse scroll or other way to enter copy-mode
		local current_im
		current_im=$(get_current_im)
		log "cmd_mode_changed: entering copy-mode, saving and switching"
		save_im "$pane_key" "$current_im"
		if [[ "$current_im" != "$DEFAULT_IM" ]]; then
			log "cmd_mode_changed: switching to $DEFAULT_IM"
			macism "$DEFAULT_IM"
		fi
	else
		# Exiting copy-mode
		log "cmd_mode_changed: exiting copy-mode"
		restore_im "$pane_key"
	fi
}

# Called by C-a binding before entering prefix mode
# Saves IM here so focus-out won't overwrite it with English
# Sets @im-saved pane option so focus-out/mode-changed know to skip saving
cmd_prefix() {
	local session="$1" pane_id="$2"
	local pane_key="${session}:${pane_id}"
	log "cmd_prefix: pane_key=$pane_key"

	# Get current IM once, use for both save and switch check
	local current_im
	current_im=$(get_current_im)
	save_im "$pane_key" "$current_im"

	# Set pane option so focus-out/mode-changed will skip saving
	tmux set-option -p -t "$pane_id" @im-saved 1

	# Switch to English if needed
	if [[ "$current_im" != "$DEFAULT_IM" ]]; then
		log "cmd_prefix: switching to $DEFAULT_IM"
		macism "$DEFAULT_IM"
	else
		log "cmd_prefix: already at default, skipping switch"
	fi
}

usage() {
	cat <<EOF
tmux-im.sh - Input method manager for tmux panes

Usage:
  tmux-im.sh focus-out <session> <pane_id>
  tmux-im.sh focus-in <session> <pane_id>
  tmux-im.sh mode-changed <session> <pane_id> [mode]
  tmux-im.sh prefix <session> <pane_id>

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
		focus-out)
			[[ $# -lt 2 ]] && { echo "error: focus-out requires <session> <pane_id>" >&2; exit 1; }
			cmd_focus_out "$1" "$2"
			;;
		focus-in)
			[[ $# -lt 2 ]] && { echo "error: focus-in requires <session> <pane_id>" >&2; exit 1; }
			cmd_focus_in "$1" "$2"
			;;
		mode-changed)
			[[ $# -lt 2 ]] && { echo "error: mode-changed requires <session> <pane_id>" >&2; exit 1; }
			cmd_mode_changed "$1" "$2" "${3:-}"
			;;
		prefix)
			[[ $# -lt 2 ]] && { echo "error: prefix requires <session> <pane_id>" >&2; exit 1; }
			cmd_prefix "$1" "$2"
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
