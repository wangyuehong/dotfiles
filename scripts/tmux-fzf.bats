#!/usr/bin/env bats
# tmux-fzf.bats: Tests for tmux-fzf.sh
#
# Run: bats scripts/tmux-fzf.bats

# === Constants ===
SCRIPT_DIR="${BATS_TEST_DIRNAME}"
SCRIPT="${SCRIPT_DIR}/tmux-fzf.sh"

# === Setup ===
setup() {
	source "$SCRIPT"
}

# === Unit tests: shorten_home_path ===

@test "AC-0020-0080: shorten_home_path: HOME/path -> ~/path" {
	run shorten_home_path "$HOME/project/main.go"
	[ "$output" = "~/project/main.go" ]
}

@test "shorten_home_path: HOME exactly -> ~" {
	run shorten_home_path "$HOME"
	[ "$output" = "~" ]
}

@test "shorten_home_path: non-HOME path unchanged" {
	run shorten_home_path "/tmp/file.txt"
	[ "$output" = "/tmp/file.txt" ]
}

# === Unit tests: format_at_prefix ===

@test "AC-0030-0050: format_at_prefix: space -> single quote" {
	run format_at_prefix "path with space.txt"
	[ "$output" = "@'path with space.txt'" ]
}

@test "AC-0030-0060: format_at_prefix: single quote escape" {
	run format_at_prefix "file'name.txt"
	[ "$output" = "@'file'\\''name.txt'" ]
}

@test "format_at_prefix: no special chars -> no quote" {
	run format_at_prefix "simple.txt"
	[ "$output" = "@simple.txt" ]
}

@test "format_at_prefix: dollar sign -> single quote" {
	run format_at_prefix 'file$var.txt'
	[ "$output" = "@'file\$var.txt'" ]
}

@test "format_at_prefix: backslash -> single quote" {
	run format_at_prefix 'file\name.txt'
	[ "$output" = "@'file\\name.txt'" ]
}

@test "format_at_prefix: backtick -> single quote" {
	run format_at_prefix 'file`cmd`.txt'
	[ "$output" = "@'file\`cmd\`.txt'" ]
}

@test "format_at_prefix: double quote -> single quote" {
	run format_at_prefix 'file"name.txt'
	[ "$output" = "@'file\"name.txt'" ]
}

# === Unit tests: format_shell_escape ===

@test "AC-0030-0080: format_shell_escape: space -> backslash escape" {
	run format_shell_escape "path with space.txt"
	[ "$output" = 'path\ with\ space.txt' ]
}

@test "AC-0030-0090: format_shell_escape: ~ path preserved" {
	run format_shell_escape "~/project/main.go"
	[ "$output" = "~/project/main.go" ]
}

@test "format_shell_escape: ~ with space preserved" {
	run format_shell_escape "~/my project/main.go"
	[ "$output" = '~/my\ project/main.go' ]
}

@test "format_shell_escape: no special chars unchanged" {
	run format_shell_escape "simple.txt"
	[ "$output" = "simple.txt" ]
}

# === Integration tests: error handling ===

@test "AC-0050-0010: non-tmux env exits with error" {
	unset TMUX
	run "$SCRIPT"
	[ "$status" -eq 1 ]
	[[ "$output" == *"must be run inside a tmux session"* ]]
}

@test "AC-0050-0020: missing fd exits with error" {
	# Save original TMUX to restore later
	local orig_tmux="${TMUX:-}"
	export TMUX="fake-tmux-session"
	# Create temp dir with mock tmux that does nothing
	local mock_dir
	mock_dir=$(mktemp -d)
	cat > "$mock_dir/tmux" << 'EOF'
#!/bin/bash
echo "mock-pane-id"
EOF
	chmod +x "$mock_dir/tmux"
	# Mock PATH: include mock dir but exclude fd/fdfind
	export PATH="$mock_dir:/usr/bin:/bin"
	run "$SCRIPT"
	rm -rf "$mock_dir"
	[ "$status" -eq 1 ]
	[[ "$output" == *"fd"*"not found"* ]]
	# Restore TMUX
	if [[ -n "$orig_tmux" ]]; then
		export TMUX="$orig_tmux"
	else
		unset TMUX
	fi
}
