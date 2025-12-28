#!/usr/bin/env bash
# tmux-im.sh: Input method manager for tmux panes
# Works with tmux-im (Go storage layer) to save/restore IM per pane
set -euo pipefail

DEFAULT_IM="${TMUX_IM_DEFAULT:-com.apple.keylayout.ABC}"
LOG_FILE="${HOME}/.cache/tmux-im/debug.log"

log() {
	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	mkdir -p "$(dirname "$LOG_FILE")"
	echo "[$timestamp] $*" >> "$LOG_FILE"
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

# Auto-detect pane key for external callers (e.g., Hammerspoon)
# Selection: prefer attached session with most recent activity
get_auto_pane() {
	# Inside tmux: use current session and pane
	if [[ -n "${TMUX:-}" ]]; then
		local session pane_id
		session=$(tmux display-message -p '#{session_name}')
		pane_id="${TMUX_PANE}"
		echo "${session}:${pane_id}"
		return 0
	fi

	# Outside tmux: find best session
	local sessions
	sessions=$(tmux list-sessions -F '#{session_attached} #{session_activity} #{session_name}' 2>/dev/null) || {
		echo "error: tmux server not running" >&2
		return 1
	}

	[[ -z "$sessions" ]] && {
		echo "error: no tmux sessions" >&2
		return 1
	}

	# Priority: attached > detached, then by activity timestamp
	local best_session="" best_activity=0 best_attached=0
	while IFS=' ' read -r attached activity session_name; do
		if ((attached && !best_attached)); then
			best_attached=1
			best_activity=$activity
			best_session=$session_name
		elif ((attached == best_attached && activity > best_activity)); then
			best_activity=$activity
			best_session=$session_name
		elif [[ -z "$best_session" ]]; then
			best_session=$session_name
			best_activity=$activity
		fi
	done <<< "$sessions"

	[[ -z "$best_session" ]] && {
		echo "error: no tmux sessions" >&2
		return 1
	}

	local pane_id
	pane_id=$(tmux display-message -t "$best_session" -p '#{pane_id}')
	echo "${best_session}:${pane_id}"
}

save_im() {
	local pane_key="$1"
	local current_im
	current_im=$(get_current_im)
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
	local im_saved
	im_saved=$(tmux show-options -pqv @im-saved)
	if [[ "$im_saved" == "1" ]]; then
		log "cmd_focus_out: skipping (already saved by prefix)"
		tmux set-option -pu @im-saved
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
		# Check if C-a was just pressed
		local im_saved
		im_saved=$(tmux show-options -pqv @im-saved)
		if [[ "$im_saved" == "1" ]]; then
			# C-a already saved IM and switched to English, skip
			log "cmd_mode_changed: entering copy-mode, skipping (already handled by prefix)"
			tmux set-option -pu @im-saved
			return 0
		fi
		# Mouse scroll or other way to enter copy-mode
		# Get current IM once, use for both save and switch check
		local current_im
		current_im=$(get_current_im)
		log "cmd_mode_changed: entering copy-mode, saving and switching"
		log "save_im: pane_key=$pane_key current_im=$current_im"
		tmux-im "$pane_key" "$current_im"
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

	# Save current IM
	log "save_im: pane_key=$pane_key current_im=$current_im"
	tmux-im "$pane_key" "$current_im"

	# Set pane option so focus-out/mode-changed will skip saving
	tmux set-option -p @im-saved 1

	# Switch to English if needed
	if [[ "$current_im" != "$DEFAULT_IM" ]]; then
		log "cmd_prefix: switching to $DEFAULT_IM"
		macism "$DEFAULT_IM"
	else
		log "cmd_prefix: already at default, skipping switch"
	fi
}

# External API for callers outside tmux (e.g., Hammerspoon)

cmd_get() {
	local pane_key
	pane_key=$(get_auto_pane) || exit 1
	tmux-im "$pane_key"
}

cmd_set() {
	local im="$1"
	local pane_key
	pane_key=$(get_auto_pane) || exit 1
	tmux-im "$pane_key" "$im"
}

usage() {
	cat <<EOF
tmux-im.sh - Input method manager for tmux panes

Usage:
  tmux-im.sh focus-out <session> <pane_id>
  tmux-im.sh focus-in <session> <pane_id>
  tmux-im.sh mode-changed <session> <pane_id> [mode]
  tmux-im.sh prefix <session> <pane_id>
  tmux-im.sh get
  tmux-im.sh set <im>

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
		get)
			cmd_get
			;;
		set)
			[[ $# -lt 1 ]] && { echo "error: set requires <im>" >&2; exit 1; }
			cmd_set "$1"
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
