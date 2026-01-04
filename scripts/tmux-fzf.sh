#!/usr/bin/env bash
set -euo pipefail

# === Utility Functions ===

# Shorten path by replacing $HOME with ~
# Usage: shorten_home_path "$HOME/file" -> "~/file"
shorten_home_path() {
	local f="$1"
	if [[ "$f" == "$HOME/"* ]]; then
		echo "~${f#$HOME}"
	elif [[ "$f" == "$HOME" ]]; then
		echo "~"
	else
		echo "$f"
	fi
}

# Format path for shell (printf %q, preserve ~ expansion)
# Usage: format_shell_escape "~/path with space" -> "~/path\ with\ space"
format_shell_escape() {
	local p="$1"
	local escaped
	if [[ "$p" == "~"* ]]; then
		printf -v escaped "%q" "${p#\~}"
		echo "~$escaped"
	else
		printf -v escaped "%q" "$p"
		echo "$escaped"
	fi
}

# Return early if sourced for testing
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0

# === Main Script ===

# --- Environment Check ---
if [[ -z "${TMUX-}" ]]; then
	echo "Error: This script must be run inside a tmux session." >&2
	exit 1
fi

# --- Pane Info ---
pane_id=$(tmux display-message -p '#{pane_id}')
pane_dir=$(tmux display-message -p '#{pane_current_path}')

# --- Git Detection ---
git_root=$(git -C "$pane_dir" rev-parse --show-toplevel 2>/dev/null || true)
in_git_repo=false
[[ -n "$git_root" ]] && in_git_repo=true

# --- Command Detection ---
if command -v fd >/dev/null 2>&1; then
	fd_cmd="fd"
elif command -v fdfind >/dev/null 2>&1; then
	fd_cmd="fdfind"
else
	echo "Error: Required command 'fd' or 'fdfind' not found." >&2
	exit 1
fi

has_grealpath=false
command -v grealpath >/dev/null 2>&1 && has_grealpath=true

# --- Preview Command ---
# Auto-detect file vs directory and use appropriate preview
if command -v bat >/dev/null 2>&1; then
	file_cmd='bat --style=numbers --color=always'
elif command -v batcat >/dev/null 2>&1; then
	file_cmd='batcat --style=numbers --color=always'
else
	file_cmd='cat'
fi

if command -v tree >/dev/null 2>&1; then
	dir_cmd='tree -C'
else
	dir_cmd='ls -ap --color=always'
fi

preview="[[ -d {} ]] && $dir_cmd {} | head -n 30 || $file_cmd {}"

# --- fd Commands ---
fd_flags="-H --exclude .git"
printf -v escaped_dir "%q" "$pane_dir"
# Static command for initial load (files only)
fd_files="$fd_cmd $fd_flags --type f --absolute-path . $escaped_dir"
# Templates for dynamic reload (base directory appended at runtime)
fd_files_tpl="$fd_cmd $fd_flags --type f --absolute-path ."
fd_dirs_tpl="$fd_cmd $fd_flags --type d --absolute-path ."
# Mixed mode: files and directories (for navigation)
fd_all_tpl="$fd_cmd $fd_flags --absolute-path ."

# --- State Files ---
mode_file=$(mktemp)
base_file=$(mktemp)
if $in_git_repo; then
	echo "git" > "$mode_file"
else
	echo "abs" > "$mode_file"
fi
echo "$pane_dir" > "$base_file"
trap "rm -f '$mode_file' '$base_file'" EXIT

# --- ANSI Colors ---
C=$'\e[38;5;203m'  # coral/salmon red
R=$'\e[0m'         # reset

# --- Prompt Builder ---
# Usage in fzf transform: builds "Type | Mode > " prompt with colors
# Expects: $type (Files/Dirs), $mode (Git/Abs/Rel)
prompt_builder="printf '%s' \"${C}\${type}${R} | ${C}\${mode}${R} > \""

# --- fzf Bindings ---
bind_switch_type="ctrl-d:transform:
	base=\$(cat '$base_file')
	printf -v esc '%q' \"\$base\"
	mode=\$(echo \"\$FZF_PROMPT\" | grep -oE '(Git|Abs|Rel)')
	[[ \$FZF_PROMPT =~ Files ]] && type=Dirs || type=Files
	[[ \$type == Dirs ]] && fd='$fd_dirs_tpl' || fd='$fd_files_tpl'
	prompt=\$($prompt_builder)
	echo \"change-prompt(\$prompt)+reload(\$fd \$esc)+first\""

if $in_git_repo; then
	default_mode=Git
	alt_mode=Abs
else
	default_mode=Abs
	alt_mode=Rel
fi

# --- Header ---
keybinds_header="C-d: Files/Dirs | C-t: ${default_mode}/${alt_mode} | C-h: Up | C-l: In"
initial_header="$(shorten_home_path "$pane_dir")
$keybinds_header"

bind_switch_path="ctrl-t:transform:
	[[ \$FZF_PROMPT =~ Files ]] && type=Files || type=Dirs
	[[ \$FZF_PROMPT =~ $alt_mode ]] && mode=$default_mode || mode=$alt_mode
	prompt=\$($prompt_builder)
	echo \"change-prompt(\$prompt)+execute-silent(sh -c 'echo \$mode | tr A-Z a-z > $mode_file')\""

bind_parent_dir="ctrl-h:transform:
	base=\$(cat '$base_file')
	parent=\$(dirname \"\$base\")
	[[ \"\$parent\" == \"\$base\" ]] && exit 0
	echo \"\$parent\" > '$base_file'
	printf -v esc '%q' \"\$parent\"
	short=\$(echo \"\$parent\" | sed 's|^$HOME|~|')
	header=\"\${short}
$keybinds_header\"
	echo \"change-header(\$header)+reload($fd_all_tpl \$esc)+first\""

bind_enter_dir="ctrl-l:transform:
	[[ ! -d {} ]] && exit 0
	dir={}
	echo \"\$dir\" > '$base_file'
	printf -v esc '%q' \"\$dir\"
	short=\$(echo \"\$dir\" | sed 's|^$HOME|~|')
	header=\"\${short}
$keybinds_header\"
	echo \"change-header(\$header)+reload($fd_all_tpl \$esc)+first\""

fzf_opts=(
	--multi --reverse
	--preview "$preview"
	--prompt "${C}Files${R} | ${C}${default_mode}${R} > "
	--header "$initial_header"
	--bind "start:reload:$fd_files"
	--bind "$bind_switch_type"
	--bind "$bind_switch_path"
	--bind "$bind_parent_dir"
	--bind "$bind_enter_dir"
)

# --- Run fzf ---
selected=$(fzf "${fzf_opts[@]}" || true)
[[ -z "$selected" ]] && exit 0

# --- Parse Selection ---
files=()
while IFS= read -r line; do
	[[ -n "$line" ]] && files+=("$line")
done <<<"$selected"

# --- Convert Paths ---
read -r mode < "$mode_file"
output=()

case "$mode" in
	abs)
		for f in "${files[@]}"; do
			output+=("$(shorten_home_path "$f")")
		done
		;;
	git|rel)
		[[ "$mode" == "git" ]] && base="$git_root" || base="$pane_dir"
		for f in "${files[@]}"; do
			# Use absolute path if file is outside base directory
			if [[ "$f" != "$base"/* ]]; then
				output+=("$(shorten_home_path "$f")")
			elif $has_grealpath; then
				output+=("$(grealpath --relative-to="$base" "$f")")
			else
				output+=("$(shorten_home_path "$f")")
			fi
		done
		;;
esac

# --- Format Output ---
result=()
for p in "${output[@]}"; do
	result+=("$(format_shell_escape "$p")")
done
printf -v out "%s " "${result[@]}"

# --- Send to Tmux ---
tmux send-keys -t "$pane_id" "$out"
