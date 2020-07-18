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
	@make upclone github_repo=sstephenson/rbenv-gem-rehash.git \
		dir=~/.rbenv/plugins/rbenv-gem-rehash
	@make upclone github_repo=sstephenson/rbenv-vars.git dir=~/.rbenv/plugins/rbenv-vars
	@make upclone github_repo=yyuu/pyenv.git dir=~/.pyenv
	@make upclone github_repo=syndbg/goenv.git dir=~/.goenv
	@make upclone github_repo=junegunn/fzf.git dir=~/.fzf
	@make upclone github_repo=denysdovhan/spaceship-prompt.git \
		dir=~/.oh-my-zsh/custom/themes/spaceship-prompt
	@ln -sf ~/.oh-my-zsh/custom/themes/spaceship-prompt/spaceship.zsh-theme ~/.oh-my-zsh/custom/themes/spaceship.zsh-theme


install_z:
	@if [ ! -f ~/.z ]; then touch ~/.z; fi
	@make upclone github_repo=rupa/z.git dir=~/.zz

ln_dotfiles:
	@for file in aliases bash_profile ctags gemrc gitconfig gitignore psqlrc tigrc tmux.conf vimrc zshrc myclirc; do \
	  echo "ln -sf $(CURR_DIR)/.$$file ~/.$$file" && ln -sf $(CURR_DIR)/.$$file ~/.$$file; \
	done;

default:
	@make ln_dotfiles
	@make install_z
	@make upclone_all
	@make update_fzf

setup:
	@make home_dirs
	@brew install tmux zsh fd rg tig git tmux-mem-cpu-load aspell

brew_up:
	@brew update && brew upgrade && brew cleanup

update_fzf:
	@~/.fzf/install --bin

fzf:
	@~/.fzf/install --all

go_tools:
	go get github.com/rogpeppe/godef
	go get golang.org/x/tools/cmd/goimports
	go get github.com/cweill/gotests/...
	go get github.com/derekparker/delve/cmd/dlv
	go get github.com/godoctor/godoctor
	go get github.com/davidrjenni/reftools/cmd/fillstruct
	go get golang.org/x/tools/cmd/godoc
	go get github.com/josharian/impl
	GO111MODULE=on go get golang.org/x/tools/gopls@latest

terminfo-24bit:
	tic -x -o ~/.terminfo terminfo-24bit.src
