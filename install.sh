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
else
    echo 'update z'
    cd ~/.zz && git pull
fi

if [ ! -d ~/.oh-my-zsh ]; then
    git clone https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
else
    echo 'update oh-my-zsh'
    cd ~/.oh-my-zsh && git pull
fi

if [ ! -d ~/.rbenv ]; then
    git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
else
    echo 'update rbenv'
    cd ~/.rbenv && git pull
fi

if [ ! -d ~/.rbenv/plugins/ruby-build ]; then
    git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
else
    echo 'update rbenv ruby-build'
    cd ~/.rbenv/plugins/ruby-build && git pull
fi

if [ ! -d ~/.rbenv/plugins/rbenv-gemset ]; then
    git clone git://github.com/jamis/rbenv-gemset.git  ~/.rbenv/plugins/rbenv-gemset
else
    echo 'update rbenv rbenv-gemset'
    cd ~/.rbenv/plugins/rbenv-gemset && git pull
fi

if [ ! -d ~/.rbenv/plugins/rbenv-gem-rehash ]; then
    git clone git://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
else
    echo 'update rbenv rbenv-rehash'
    cd ~/.rbenv/plugins/rbenv-gem-rehash && git pull
fi
ln -sf $cwd/_tmux.conf ~/.tmux.conf
ln -sf $cwd/_zshrc ~/.zshrc
ln -sf $cwd/_zshrc_alias ~/.zshrc_alias
ln -sf $cwd/_bashrc ~/.bashrc
ln -sf $cwd/_bash_alias ~/.bash_alias
ln -sf $cwd/_bash_profile ~/.bash_profile
ln -sf $cwd/_gitconfig ~/.gitconfig
ln -sf $cwd/_gitignore ~/.gitignore
ln -sf $cwd/_gemrc ~/.gemrc
ln -sf $cwd/_vimrc ~/.vimrc

exit 0
