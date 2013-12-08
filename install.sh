#!/bin/sh

cwd=$(pwd)

if [ ! -d $HOME/.zz ]; then
    git clone git@github.com:rupa/z.git $HOME/.zz
fi

if [ ! -d $HOME/.oh-my-zsh ]; then
    git clone git@github.com:robbyrussell/oh-my-zsh.git $HOME/.oh-my-zsh
fi

if [ ! -d $HOME/.rbenv ]; then
    git clone git@github.com:sstephenson/rbenv.git $HOME/.rbenv
fi

ln -sf $cwd/_tmux.conf $HOME/.tmux.conf
ln -sf $cwd/_zshrc $HOME/.zshrc
ln -sf $cwd/_bashrc $HOME/.bashrc
ln -sf $cwd/_bash_profile $HOME/.bash_profile
ln -sf $cwd/_gitconfig $HOME/.gitconfig
ln -sf $cwd/_gitignore $HOME/.gitignore

exit 0
