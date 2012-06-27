#!/bin/bash

# Quick and dirty script to compile Enlightenment 17 and dependencies

function run() {

    echo "running $*"
    sh -c "$*" &>> /tmp/ebuild.log

    if [[ $? == 0 ]]; then
        echo "successfully ran $*"
    else
        echo "failed to run $*"
        cd ..
        exit 1
    fi
}

function ecompile() {
    echo "compiling $1"

    cd $1

    run "./autogen.sh --prefix=/opt/e17/trunk"
    run "make -j5"
    run "sudo make install"

    cd ..
}

rm /tmp/ebuild.log

ecompile "eina"
ecompile "eet"
ecompile "evas"
ecompile "ecore"
ecompile "eio"
ecompile "e_dbus"
ecompile "efreet"
ecompile "eeze"
ecompile "embryo"
ecompile "edje"
ecompile "e"
ecompile "elementary"
