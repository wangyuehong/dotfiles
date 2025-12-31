#!/usr/bin/env bash
# tmux-im.sh: Input method manager for tmux panes
#
# Pane options used:
#   @im           - Saved input method state
#   @im-saved     - Protection flag (1 = skip sync save during prefix/copy-mode)
#   @im-color     - Border color for tmux format #{@im-color}
#   @focus_out_ts - Timestamp of last focus-out (for debounce)
#
# Called by:
#   - tmux hooks (focus-out, focus-in, mode-changed, prefix)
#   - Hammerspoon (sync) when input method changes in terminal
#
# Hammerspoon is single-threaded and uses hs.execute() synchronously,
# so concurrent calls are not possible. No locking needed.
set -euo pipefail

DEFAULT_IM="${TMUX_IM_DEFAULT:-com.apple.keylayout.ABC}"
LOG_FILE="${TMUX_IM_LOG:-${HOME}/.cache/tmux-im/debug.log}"

# Debounce threshold for spurious focus events (milliseconds)
# macism causes rapid focus-out/focus-in (~20ms), normal pane switch is much slower
FOCUS_DEBOUNCE_MS=50

_init_log() {
	mkdir -p "$(dirname "$LOG_FILE")"
	_timestamp() { gdate '+%Y-%m-%d %H:%M:%S.%6N'; }
	log() {
		echo "[$(_timestamp)] $*" >> "$LOG_FILE"
	}
}
_init_log

# Get current timestamp in milliseconds (requires gdate)
get_timestamp_ms() {
	gdate +%s%3N
}

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

# Get saved IM for pane, returns DEFAULT_IM if not set
get_saved_im() {
	local pane_id="$1"
	local im
	im=$(tmux show-options -pqv -t "$pane_id" @im 2>/dev/null) || true
	echo "${im:-$DEFAULT_IM}"
}

# Check if pane is protected (prefix/copy-mode saved IM)
is_protected() {
	local pane_id="$1"
	local im_saved
	im_saved=$(tmux show-options -pqv -t "$pane_id" @im-saved 2>/dev/null) || true
	[[ "$im_saved" == "1" ]]
}

# Clear protection flag
clear_protection() {
	local pane_id="$1"
	tmux set-option -pu -t "$pane_id" @im-saved 2>/dev/null || true
}

# Set protection flag
set_protection() {
	local pane_id="$1"
	tmux set-option -p -t "$pane_id" @im-saved 1
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

save_im() {
	local pane_id="$1" im="$2"
	tmux set-option -p -t "$pane_id" @im "$im"
}

# Save current IM and switch to English (for prefix/copy-mode)
# Sets global: SAVED_IM (saved IM ID), SWITCHED (1 if switched, 0 otherwise)
save_and_switch_to_english() {
	local pane_id="$1"
	SAVED_IM=$(get_current_im)
	save_im "$pane_id" "$SAVED_IM"
	set_protection "$pane_id"
	if [[ "$SAVED_IM" != "$DEFAULT_IM" ]]; then
		switch_im "$DEFAULT_IM"
		SWITCHED=1
	else
		SWITCHED=0
	fi
}

# Full restore: clear protection, update border, restore IM
# Sets global: RESTORED_IM for caller logging
restore_pane_im() {
	local pane_id="$1"
	clear_protection "$pane_id"
	RESTORED_IM=$(get_saved_im "$pane_id")
	update_border_color "$pane_id" "$RESTORED_IM"
	switch_im "$RESTORED_IM"
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

cmd_focus_out() {
	local pane_id="$1"
	tmux set-option -p -t "$pane_id" @focus_out_ts "$(get_timestamp_ms)"
	log "focus_out: pane=$pane_id"
}

# Check if focus-in is spurious (caused by macism window switching)
# Returns 0 if spurious, 1 if normal
# Sets SPURIOUS_ELAPSED_MS for caller to use in log
is_spurious_focus_in() {
	local pane_id="$1"
	local out_ts now

	out_ts=$(tmux show-options -pqv -t "$pane_id" @focus_out_ts 2>/dev/null || echo "")
	[[ -z "$out_ts" ]] && return 1

	now=$(get_timestamp_ms)
	SPURIOUS_ELAPSED_MS=$((now - out_ts))
	tmux set-option -pu -t "$pane_id" @focus_out_ts 2>/dev/null || true

	[[ $SPURIOUS_ELAPSED_MS -lt $FOCUS_DEBOUNCE_MS ]]
}

cmd_focus_in() {
	local pane_id="$1"

	if is_spurious_focus_in "$pane_id"; then
		# Spurious focus caused by macism window switching
		if is_protected "$pane_id"; then
			# Triggered by prefix/copy-mode, skip to protect saved IM
			log "focus_in: pane=$pane_id | spurious ${SPURIOUS_ELAPSED_MS}ms | skip (protected)"
			return 0
		fi
		# Triggered externally (e.g., Emacs), sync current IM
		local current_im
		current_im=$(get_current_im)
		save_im "$pane_id" "$current_im"
		update_border_color "$pane_id" "$current_im"
		log "focus_in: pane=$pane_id | spurious ${SPURIOUS_ELAPSED_MS}ms | sync im=$(short_im "$current_im")"
		return 0
	fi

	# Normal focus-in: restore saved IM
	restore_pane_im "$pane_id"
	log "focus_in: pane=$pane_id | restore im=$(short_im "$RESTORED_IM")"
}

cmd_mode_changed() {
	local pane_id="$1" mode="${2:-}"

	if [[ -n "$mode" ]]; then
		# Entering copy-mode
		if is_protected "$pane_id"; then
			# C-a already saved IM and switched to English, skip
			log "mode_changed: pane=$pane_id | enter $mode | skip (prefix handled)"
			return 0
		fi
		# Mouse scroll or other way to enter copy-mode
		save_and_switch_to_english "$pane_id"
		if [[ $SWITCHED -eq 1 ]]; then
			log "mode_changed: pane=$pane_id | enter $mode | save im=$(short_im "$SAVED_IM") | switch to ABC"
		else
			log "mode_changed: pane=$pane_id | enter $mode | save im=ABC | no switch"
		fi
	else
		# Exiting copy-mode
		restore_pane_im "$pane_id"
		log "mode_changed: pane=$pane_id | exit copy-mode | restore im=$(short_im "$RESTORED_IM")"
	fi
}

cmd_prefix() {
	local pane_id="$1"
	save_and_switch_to_english "$pane_id"
	if [[ $SWITCHED -eq 1 ]]; then
		log "prefix: pane=$pane_id | save im=$(short_im "$SAVED_IM") | switch to ABC"
	else
		log "prefix: pane=$pane_id | save im=ABC | no switch"
	fi
}

# Hammerspoon handler
cmd_sync() {
	local source_id="$1"

	tmux has-session 2>/dev/null || exit 0

	local pane_id
	pane_id=$(tmux display-message -p '#{pane_id}' 2>/dev/null) || true
	[[ -z "$pane_id" ]] && exit 0

	# Save IM unless protected (prefix/copy-mode already saved)
	if is_protected "$pane_id"; then
		log "sync: pane=$pane_id | im=$(short_im "$source_id") | skip save (protected)"
	else
		save_im "$pane_id" "$source_id"
		log "sync: pane=$pane_id | im=$(short_im "$source_id") | saved"
	fi
	update_border_color "$pane_id" "$source_id"
}

usage() {
	cat <<EOF
tmux-im.sh - Input method manager for tmux panes

Usage:
  tmux-im.sh focus-out <pane_id>
  tmux-im.sh focus-in <pane_id>
  tmux-im.sh mode-changed <pane_id> [mode]
  tmux-im.sh prefix <pane_id>
  tmux-im.sh sync <source_id>

Commands:
  focus-out     Record timestamp for spurious focus detection (tmux hook)
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
		focus-out)
			[[ $# -lt 1 ]] && { echo "error: focus-out requires <pane_id>" >&2; exit 1; }
			cmd_focus_out "$1"
			;;
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

# Allow sourcing without executing main (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
