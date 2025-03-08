# MAKEFLAGS += --silent
default: all

CURR_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: home-dirs
home-dirs:
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
upclone-all:
	@make upclone github_repo=robbyrussell/oh-my-zsh.git dir=~/.oh-my-zsh
	@make upclone github_repo=zsh-users/zsh-syntax-highlighting.git \
		dir=~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
	@make upclone github_repo=zsh-users/zsh-autosuggestions.git \
		dir=~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
	@make upclone github_repo=rbenv/rbenv.git dir=~/.rbenv
	@make upclone github_repo=rbenv/ruby-build.git dir=~/.rbenv/plugins/ruby-build
	@make upclone github_repo=rbenv/rbenv-vars.git dir=~/.rbenv/plugins/rbenv-vars
	@make upclone github_repo=yyuu/pyenv.git dir=~/.pyenv
	@make upclone github_repo=syndbg/goenv.git dir=~/.goenv
	@make upclone github_repo=nodenv/nodenv.git dir=~/.nodenv
	@make upclone github_repo=nodenv/node-build.git dir=~/.nodenv/plugins/node-build
	@make upclone github_repo=denysdovhan/spaceship-prompt.git \
		dir=~/.oh-my-zsh/custom/themes/spaceship-prompt
	@make upclone github_repo=tmux-plugins/tpm.git dir=~/.tmux/plugins/tpm
	@ln -sf ~/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme ~/.oh-my-zsh/custom/themes/spaceship.zsh-theme

.PHONY: ln-dotfiles
ln-dotfiles:
	@for file in aliases bash_profile zprofile ctags gemrc gitconfig gitignore psqlrc tigrc tmux.conf vimrc zshrc myclirc ripgreprc; do \
	  echo "ln -sf $(CURR_DIR)/.$$file ~/.$$file" && ln -sf $(CURR_DIR)/.$$file ~/.$$file; \
	done;
	ln -sf $(CURR_DIR)/direnv.toml ~/.config/direnv/direnv.toml
	ln -sf $(CURR_DIR)/tmux-nerd-font-window-name.yml ~/.config/tmux/tmux-nerd-font-window-name.yml
	ln -sf $(CURR_DIR)/.editorconfig ~/.editorconfig
	ln -sf $(CURR_DIR)/ghostty.toml ~/.config/ghostty/config

.PHONY: ln-scripts
ln-scripts:
	ln -sf $(CURR_DIR)/scripts/worktree.sh ~/bin/worktree.sh

.PHONY: all
all:
	@make upclone-all
	@make brew-up
	@~/.tmux/plugins/tpm/bin/update_plugins all
	@make go-tools

.PHONY: setup
setup:
	@make home-dirs
	@mkdir -p ~/.config/direnv
	@mkdir -p ~/.config/tmux/
	@mkdir -p ~/.config/ghostty
	@brew install -q tmux zsh fd fzf rg tig git aspell z yq direnv libvterm universal-ctags tmux-mem-cpu-load
	@brew tap daipeihust/tap && brew install -q im-select
	@~/.tmux/plugins/tpm/bin/install_plugins
	@make ln-dotfiles
	@make ln-scripts

.PHONY: brew-up
brew-up:
	@brew update && brew upgrade && brew cleanup -s

.PHONY: go-tools
go-tools:
	@go install github.com/rogpeppe/godef@latest
	@go install golang.org/x/tools/cmd/goimports@latest
	@go install golang.org/x/tools/cmd/deadcode@latest
	@go install github.com/cweill/gotests/...@latest
	@go install github.com/go-delve/delve/cmd/dlv@latest
	@go install github.com/fatih/gomodifytags@latest
	@go install golang.org/x/tools/cmd/godoc@latest
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install mvdan.cc/gofumpt@latest
	@go install honnef.co/go/tools/cmd/staticcheck@latest
	@go install golang.org/x/tools/gopls@latest

.PHONY: terminfo
terminfo:
	tic -x -o ~/.terminfo terminfo-24bit.src
	tic -x -o ~/.terminfo terminfo-italic.src
