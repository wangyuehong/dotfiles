# MAKEFLAGS += --silent
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-print-directory

.DEFAULT_GOAL := all

CURR_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: help
help: ## 列出所有可用目标
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: home-dirs
home-dirs: ## 创建 ~/bin 与 ~/go 目录
	@mkdir -p ~/bin
	@mkdir -p ~/go

.PHONY: upclone
upclone:
	@echo upclone $(dir)
	@if [ ! -d $(dir) ]; then \
	  git clone --depth 1 https://github.com/$(github_repo) $(dir); \
	else \
	  cd $(dir) && git pull; \
	fi

.PHONY: upclone-all
upclone-all: ## 克隆或更新 oh-my-zsh、tpm 等外部仓库
	@$(MAKE) upclone github_repo=robbyrussell/oh-my-zsh.git dir=~/.oh-my-zsh
	@$(MAKE) upclone github_repo=zsh-users/zsh-syntax-highlighting.git \
		dir=~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
	@$(MAKE) upclone github_repo=zsh-users/zsh-autosuggestions.git \
		dir=~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
	@$(MAKE) upclone github_repo=denysdovhan/spaceship-prompt.git \
		dir=~/.oh-my-zsh/custom/themes/spaceship-prompt
	@$(MAKE) upclone github_repo=tmux-plugins/tpm.git dir=~/.tmux/plugins/tpm
	@ln -sf ~/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme ~/.oh-my-zsh/custom/themes/spaceship.zsh-theme

.PHONY: ln-dotfiles
ln-dotfiles: ## 符号链接 dotfiles 到 ~/ 与 ~/.config/
	@for file in aliases bash_profile zprofile ctags gitconfig gitignore psqlrc tigrc tmux.conf vimrc \
		zshrc myclirc ripgreprc editorconfig; do \
	  echo "ln -sf $(CURR_DIR)/.$$file ~/.$$file" && ln -sf $(CURR_DIR)/.$$file ~/.$$file; \
	done;
	ln -sf $(CURR_DIR)/direnv.toml ~/.config/direnv/direnv.toml
	ln -sf $(CURR_DIR)/direnvrc ~/.config/direnv/direnvrc
	ln -sf $(CURR_DIR)/ghostty.toml ~/.config/ghostty/config
	ln -sf $(CURR_DIR)/mise.toml ~/.config/mise/config.toml

.PHONY: ln-scripts
ln-scripts: ## 符号链接 scripts/ 下指定脚本到 ~/bin/
	@for script in worktree.sh tmux-fzf.sh tmux-im.sh tmux-window-name.sh; do \
		chmod +x $(CURR_DIR)/scripts/$$script && \
		ln -sf $(CURR_DIR)/scripts/$$script ~/bin/$$script; \
	done


.PHONY: all
all: ## 全量更新：oh-my-zsh、Homebrew、tmux 插件、Go 工具
	@$(MAKE) upclone-all
	@$(MAKE) brew-up
	@~/.tmux/plugins/tpm/bin/update_plugins all
	@$(MAKE) go-tools

.PHONY: setup
setup: ## 首次安装：创建目录、安装 Homebrew 包、链接 dotfiles 和脚本
	@$(MAKE) home-dirs
	@mkdir -p ~/.config/direnv
	@mkdir -p ~/.config/tmux
	@mkdir -p ~/.config/ghostty
	@mkdir -p ~/.config/mise
	@brew install -q coreutils mise tmux zsh fd fzf ripgrep tig git jq aspell z yq direnv universal-ctags tmux-mem-cpu-load trash bats-core
	@brew install --cask -q --force font-maple-mono-normal-nl-nf-cn font-sauce-code-pro-nerd-font
	@brew tap laishulu/homebrew && brew install -q macism
	@$(MAKE) ln-dotfiles
	@$(MAKE) ln-scripts
	@~/.tmux/plugins/tpm/bin/install_plugins

.PHONY: brew-up
brew-up: ## 更新 Homebrew formulae 与 cask
	@brew update && brew upgrade --greedy && brew cleanup -s

.PHONY: go-tools
go-tools: ## 安装或更新 Go 工具（gopls、golangci-lint 等）
	@go install github.com/rogpeppe/godef@latest
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install golang.org/x/tools/cmd/deadcode@latest
	@go install github.com/cweill/gotests/...@latest
	@go install github.com/go-delve/delve/cmd/dlv@latest
	@go install github.com/fatih/gomodifytags@latest
	@go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
	@go install mvdan.cc/gofumpt@latest
	@go install honnef.co/go/tools/cmd/staticcheck@latest
	@go install golang.org/x/tools/gopls@latest

.PHONY: py-tools
py-tools: ## 安装或更新 Python 工具（ruff、uv、basedpyright、ty）
	@brew install ruff uv
	@uv tool install basedpyright
	@uv tool install ty

.PHONY: mise-tools
mise-tools: ## 信任 mise 配置，提示编辑 config.local.toml
	@mise trust ~/.dotfiles/mise.toml
	@echo "Edit ~/.config/mise/config.local.toml to add tools"

.PHONY: test
test: ## 运行全部 BATS 测试
	@bats scripts/tmux-im.bats scripts/tmux-fzf.bats scripts/tmux-window-name.bats
