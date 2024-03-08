#!/bin/bash

# Install packages
packages="apache2 openvm-tools net-tools wget curl vim imagemagick "

for install_package in ${packages[@]}; do
    echo $install_package
    #apt-get install --only-upgrade $install_package
done
