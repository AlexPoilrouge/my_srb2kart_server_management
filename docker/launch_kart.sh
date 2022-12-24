#!/bin/bash



if [ "$1" == "simple" ]; then
    ADDONS=$(ls /kart_home/addons)
    shift

    if [ -z "$ADDONS" ]; then
        srb2kart -dedicated -home /kart_home $*
        exit
    fi

    # Intentional word splitting
    srb2kart -dedicated -home /kart_home $* -file $ADDONS
else
    sudo -u strashbot bash -c "cd /kart_home && sh .srb2kart/server_start.sh"
fi