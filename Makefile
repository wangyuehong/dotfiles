MAKEFLAGS += --silent
default: default

CURR_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

home_dirs:
	@mkdir -p ~/bin
	@mkdir -p ~/go

upclone:
	@echo upclone $(dir)
	@if [ ! -d $(dir) ]; then \
	  git clone --depth 1 https://github.com/$(github_repo) $(dir); \
	else \
	  cd $(dir) && git pull; \
	fi

upclone_all:
	@make upclone github_repo=robbyrussell/oh-my-zsh.git dir=~/.oh-my-zsh
	@make upclone github_repo=zsh-users/zsh-syntax-highlighting.git \
		dir=~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
	@make upclone github_repo=zsh-users/zsh-autosuggestions.git \
		dir=~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
	@make upclone github_repo=sstephenson/rbenv.git dir=~/.rbenv
	@make upclone github_repo=sstephenson/ruby-build.git dir=~/.rbenv/plugins/ruby-build
	@make upclone github_repo=sstephenson/rbenv-vars.git dir=~/.rbenv/plugins/rbenv-vars
	@make upclone github_repo=yyuu/pyenv.git dir=~/.pyenv
	@make upclone github_repo=syndbg/goenv.git dir=~/.goenv
	@make upclone github_repo=denysdovhan/spaceship-prompt.git \
		dir=~/.oh-my-zsh/custom/themes/spaceship-prompt
	@make upclone github_repo=tmux-plugins/tpm.git dir=~/.tmux/plugins/tpm
	@ln -sf ~/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme ~/.oh-my-zsh/custom/themes/spaceship.zsh-theme

ln_dotfiles:
	@for file in aliases bash_profile zprofile ctags gemrc gitconfig gitignore psqlrc tigrc tmux.conf vimrc zshrc myclirc; do \
	  echo "ln -sf $(CURR_DIR)/.$$file ~/.$$file" && ln -sf $(CURR_DIR)/.$$file ~/.$$file; \
	done;

default:
	make ln_dotfiles
	make upclone_all
	make brew_up
	make go_tools

setup:
	@make home_dirs
	@brew install tmux zsh fd rg tig git tmux-mem-cpu-load aspell fzf z

brew_up:
	brew update && brew upgrade && brew cleanup

go_tools:
	go install github.com/rogpeppe/godef@latest
	go install golang.org/x/tools/cmd/goimports@latest
	go install github.com/cweill/gotests/...@latest
	go install github.com/go-delve/delve/cmd/dlv@latest
	go install github.com/fatih/gomodifytags@latest
	go install github.com/davidrjenni/reftools/cmd/fillstruct@latest
	go install golang.org/x/tools/cmd/godoc@latest
	go install github.com/josharian/impl@latest
	GO111MODULE=on go install golang.org/x/tools/gopls@latest

terminfo-24bit:
	tic -x -o ~/.terminfo terminfo-24bit.src
