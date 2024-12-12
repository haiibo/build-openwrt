#!/bin/bash

[ -d files/root ] || mkdir -p files/root

# Clone oh-my-zsh repository
git clone -q https://github.com/ohmyzsh/ohmyzsh files/root/.oh-my-zsh

# Install extra plugins
git clone -q https://github.com/zsh-users/zsh-autosuggestions files/root/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone -q https://github.com/zsh-users/zsh-syntax-highlighting files/root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone -q https://github.com/zsh-users/zsh-completions files/root/.oh-my-zsh/custom/plugins/zsh-completions

# Get .zshrc dotfile
cp $GITHUB_WORKSPACE/scripts/.zshrc files/root
