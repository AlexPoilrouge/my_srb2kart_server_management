#!/bin/bash


EXTENSIONS=(pk7 kart lua wad pk3)

ls_restricted() {
    for i in "${EXTENSIONS[@]}"; do
        if [ "$2" != "" ]; then
            (ls "$1"/* | grep -i "$2" | grep -i ".${i}$") 2>/dev/null
        else
            (ls "$1"/* | grep -i ".${i}$") 2>/dev/null
        fi
    done
}

