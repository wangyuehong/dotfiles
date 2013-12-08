#!/bin/sh

cwd=$(pwd)

if [ ! -f $cwd/_zshrc ]; then
    echo "run this sh in git folder"
    exit 1;
fi

if [ ! -d ~/.zz ]; then
    git clone https://github.com/rupa/z.git ~/.zz
    if [ ! -f ~/.z ]; then
        touch ~/.z
    fi
fi

if [ ! -d ~/.oh-my-zsh ]; then
    git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
fi

if [ ! -d ~/.rbenv ]; then
    git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
    git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

ln -sf $cwd/_tmux.conf ~/.tmux.conf
ln -sf $cwd/_zshrc ~/.zshrc
ln -sf $cwd/_zshrc_alias ~/.zshrc_alias
ln -sf $cwd/_bashrc ~/.bashrc
ln -sf $cwd/_bash_profile ~/.bash_profile
ln -sf $cwd/_gitconfig ~/.gitconfig
ln -sf $cwd/_gitignore ~/.gitignore

exit 0
