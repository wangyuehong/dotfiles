#!/usr/bin/env bash
set -euo pipefail

# Open the path or URL under the mouse: URLs go to the system opener,
# files go to the Emacs pane of the same session via emacsclient.
#
# Called from a tmux mouse binding:
#   tmux-open.sh <session_id> <pane_current_path> <mouse_x> <mouse_line> <mouse_hyperlink>

# Characters that end a token, besides whitespace.
# Includes full-width punctuation that surrounds paths in CJK prose.
TOKEN_DELIMS=$'\'"`()[]{}<>|（）【】「」『』《》，。、：；！？“”‘’　'

# Punctuation stripped from the end of a token (sentence ends, list commas).
TRAILING_PUNCT='.,;:!?'

# Display width of one character into REPLY: 2 for East Asian wide and emoji ranges, 1 otherwise.
# Sets REPLY instead of printing so the per-character loop in token_at does not fork.
char_width() {
	local cp
	printf -v cp '%d' "'$1"
	if ((cp >= 0x1100 && cp <= 0x115F)) ||
		((cp >= 0x2E80 && cp <= 0xA4CF)) ||
		((cp >= 0xAC00 && cp <= 0xD7A3)) ||
		((cp >= 0xF900 && cp <= 0xFAFF)) ||
		((cp >= 0xFE30 && cp <= 0xFE4F)) ||
		((cp >= 0xFF00 && cp <= 0xFF60)) ||
		((cp >= 0xFFE0 && cp <= 0xFFE6)) ||
		((cp >= 0x1F300 && cp <= 0x1FAFF)) ||
		((cp >= 0x20000 && cp <= 0x3FFFD)); then
		REPLY=2
	else
		REPLY=1
	fi
}

is_delim() {
	[[ "$1" =~ [[:space:]] || "$TOKEN_DELIMS" == *"$1"* ]]
}

# Token covering display column x (0-based) of line; empty when x hits a delimiter.
# Usage: token_at "see foo.go:12, ok" 6 -> "foo.go:12"
token_at() {
	local line="$1" x="$2"
	local -a chars=()
	local i col=0 hit=-1 w
	for ((i = 0; i < ${#line}; i++)); do
		chars+=("${line:i:1}")
		char_width "${line:i:1}"
		w=$REPLY
		if ((hit < 0 && x >= col && x < col + w)); then
			hit=$i
		fi
		((col += w))
	done
	((hit < 0)) && return 0
	is_delim "${chars[hit]}" && return 0

	local start=$hit end=$hit
	while ((start > 0)) && ! is_delim "${chars[start - 1]}"; do ((--start)); done
	while ((end < ${#chars[@]} - 1)) && ! is_delim "${chars[end + 1]}"; do ((++end)); done

	local token="${line:start:end-start+1}"
	token="${token#@}"
	while [[ -n "$token" && "$TRAILING_PUNCT" == *"${token: -1}"* ]]; do
		token="${token%?}"
	done
	echo "$token"
}

# Split a location into LOC_PATH, LOC_LINE and LOC_COL; missing parts are empty.
# Accepts "path:line[-end][:col]" and the link fragment form "path#Lline[Ccol][-Lend]".
# Sets variables like char_width, so callers need no subshell or parsing.
# Usage: split_location "a.go:12:3" -> LOC_PATH=a.go LOC_LINE=12 LOC_COL=3
split_location() {
	local s="$1"
	LOC_PATH="$s" LOC_LINE="" LOC_COL=""
	if [[ "$s" =~ ^(.+)#L([0-9]+)(C([0-9]+))?(-L?[0-9]+)?$ ]]; then
		LOC_PATH="${BASH_REMATCH[1]}" LOC_LINE="${BASH_REMATCH[2]}" LOC_COL="${BASH_REMATCH[4]}"
	# Two patterns because ERE has no lazy match: "(.+)" would swallow ":line" of "path:line:col".
	elif [[ "$s" =~ ^(.+):([0-9]+)(-[0-9]+)?:([0-9]+)$ ]]; then
		LOC_PATH="${BASH_REMATCH[1]}" LOC_LINE="${BASH_REMATCH[2]}" LOC_COL="${BASH_REMATCH[4]}"
	elif [[ "$s" =~ ^(.+):([0-9]+)(-[0-9]+)?$ ]]; then
		LOC_PATH="${BASH_REMATCH[1]}" LOC_LINE="${BASH_REMATCH[2]}"
	fi
}

# Path of a file:// URL with percent-escapes decoded.
# Usage: file_url_path "file:///tmp/a%20b.go" -> "/tmp/a b.go"
file_url_path() {
	local p="${1#file://}"
	p="/${p#*/}"
	printf '%b\n' "${p//%/\\x}"
}

# Absolute path for p: ~ expands to HOME, relative paths resolve against cwd.
resolve_path() {
	local p="$1" cwd="$2"
	case "$p" in
	"~") echo "$HOME" ;;
	"~/"*) echo "$HOME/${p#\~/}" ;;
	/*) echo "$p" ;;
	*) echo "$cwd/$p" ;;
	esac
}

# Stays NOTIFY_MS even when the mouse release or a key press arrives; -l keeps "#" in paths literal.
NOTIFY_MS=2000
notify() {
	tmux display-message -N -C -l -d "$NOTIFY_MS" "tmux-open: $1"
}

find_emacs_pane() {
	local session="$1" panes id cmd
	# Captured first so a list-panes failure aborts instead of reading as "no Emacs pane".
	# Explicit return: callers run this in $(...), where errexit is not inherited.
	panes=$(tmux list-panes -s -t "$session" -F '#{pane_id} #{pane_current_command}') || return
	while read -r id cmd; do
		if [[ "$cmd" =~ ^[Ee]macs ]]; then
			echo "$id"
			return 0
		fi
	done <<<"$panes"
}

open_in_emacs() {
	local session="$1" path="$2" line="$3" col="$4"
	local pane
	pane=$(find_emacs_pane "$session") || return
	if [[ -z "$pane" ]]; then
		notify "no Emacs pane in this session"
		return 0
	fi
	local -a args=(-n)
	[[ -n "$line" ]] && args+=("+$line${col:+:$col}")
	emacsclient "${args[@]}" "$path" >/dev/null
	tmux select-window -t "$pane"
	tmux select-pane -t "$pane"
}

main() {
	if (($# != 5)); then
		echo "Usage: tmux-open.sh <session_id> <pane_current_path> <mouse_x> <mouse_line> <mouse_hyperlink>" >&2
		exit 2
	fi
	local session="$1" cwd="$2" x="$3" text="$4" link="$5"

	local token=""
	[[ -n "$text" && -n "$x" ]] && token=$(token_at "$text" "$x")
	local target="${link:-$token}"
	if [[ -z "$target" ]]; then
		notify "no path or URL under the mouse"
		return 0
	fi
	if [[ "$target" != file://* && "$target" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
		open "$target"
		return 0
	fi

	split_location "$target"
	local path="$LOC_PATH" line="$LOC_LINE" col="$LOC_COL"
	# A link without a line number may still show one in its visible text.
	if [[ -n "$link" && -z "$line" ]]; then
		split_location "$token"
		line="$LOC_LINE" col="$LOC_COL"
	fi
	if [[ "$path" == file://* ]]; then
		path=$(file_url_path "$path")
	else
		path=$(resolve_path "$path" "$cwd")
	fi

	if [[ ! -e "$path" ]]; then
		notify "not found: $path"
		return 0
	fi
	open_in_emacs "$session" "$path" "$line" "$col"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
