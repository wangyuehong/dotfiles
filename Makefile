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
	@make upclone github_repo=denysdovhan/spaceship-prompt.git \
		dir=~/.oh-my-zsh/custom/themes/spaceship-prompt
	@ln -sf ~/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme ~/.oh-my-zsh/custom/themes/spaceship.zsh-theme

ln_dotfiles:
	@for file in asdfrc aliases bash_profile zprofile ctags gemrc gitconfig gitignore psqlrc tigrc tmux.conf vimrc zshrc myclirc; do \
	  echo "ln -sf $(CURR_DIR)/.$$file ~/.$$file" && ln -sf $(CURR_DIR)/.$$file ~/.$$file; \
	done;

default:
	@make ln_dotfiles
	@make upclone_all
	@brew upgrade --fetch-HEAD goenv
	@asdf plugin update ruby
	@make brew_up
	@make go_tools

setup:
	@make home_dirs
	@brew install tmux zsh fd rg tig git tmux-mem-cpu-load aspell asdf fzf z
	@brew install --HEAD goenv
	@make asdf

asdf:
	@brew install asdf
	# asdf plugin list | grep -q golang || asdf plugin-add golang https://github.com/kennyp/asdf-golang.git
	asdf plugin list | grep -q ruby || asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

brew_up:
	@brew update && brew upgrade && brew cleanup

go_tools:
	go get github.com/rogpeppe/godef
	go get golang.org/x/tools/cmd/goimports
	go get github.com/cweill/gotests/...
	go get github.com/go-delve/delve/cmd/dlv
	go get github.com/godoctor/godoctor
	go get github.com/davidrjenni/reftools/cmd/fillstruct
	go get golang.org/x/tools/cmd/godoc
	go get github.com/josharian/impl
	GO111MODULE=on go get golang.org/x/tools/gopls@latest

terminfo-24bit:
	tic -x -o ~/.terminfo terminfo-24bit.src
