MAKEFLAGS += --silent
default: install

CURR_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

upclone:
	@echo upclone $(dir)
	@if [ ! -d $(dir) ]; then git clone https://github.com/$(github_repo) $(dir); else cd $(dir) && git pull; fi

upclone_all:
	@make upclone github_repo=rupa/z.git dir=~/.zz
	@make upclone github_repo=robbyrussell/oh-my-zsh.git dir=~/.oh-my-zsh
	@make upclone github_repo=zsh-users/zsh-syntax-highlighting.git dir=~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
	@make upclone github_repo=sstephenson/rbenv.git dir=~/.rbenv
	@make upclone github_repo=sstephenson/ruby-build.git dir=~/.rbenv/plugins/ruby-build
	@make upclone github_repo=sstephenson/rbenv-gem-rehash.git dir=~/.rbenv/plugins/rbenv-gem-rehash
	@make upclone github_repo=sstephenson/rbenv-vars.git dir=~/.rbenv/plugins/rbenv-vars
	@make upclone github_repo=junegunn/fzf.git dir=~/.fzf
	# @make upclone github_repo=yyuu/pyenv.git dir=~/.pyenv
	# @make upclone github_repo=tokuhirom/plenv.git dir= ~/.plenv
	# @make upclone github_repo=tokuhirom/Perl-Build.git dir=~/.plenv/plugins/perl-build

prepare_z:
	@if [ ! -f ~/.z ]; then touch ~/.z; fi

install_fzf:
	@~/.fzf/install --all

ln_all:
	@for file in .{agignore,aliases,bashrc,bash_profile,ctags,gemrc,gitconfig,gitignore,psqlrc,tigrc,tmux.conf,vimrc,zshrc}; do \
		echo "ln -sf $(CURR_DIR)/$$file ~/$$file" && ln -sf $(CURR_DIR)/$$file ~/$$file; \
	done;

install:
	@make prepare_z
	@make upclone_all
	@make install_fzf
	@make ln_all