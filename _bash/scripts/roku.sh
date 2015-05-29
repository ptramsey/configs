#!/bin/bash

_roku_command() {
    local roku_ip
    roku_ip=$(cat ~/.config/ptr/roku_ip)
    curl -d '' http://$roku_ip:8060$1
}

_roku_keypress() {
    _roku_command /keypress/$1
}

_roku_keyboard() {(
    stty -echo
    trap 'stty echo' EXIT

    while IFS= read -n 1 key; do
        case "$key" in
        ""|"")
            echo
            break
            ;;
        "")
            _roku_keypress Backspace
            echo -ne '\b \b'
            ;;
        *)
            echo -n "$key"
            ;;&
        " ")
            key=+
            ;;&
        *)
            _roku_keypress Lit_$key
            ;;
        esac
    done
)}

_roku() {
    for ii in $(seq 1 $2); do
        case "$1" in
            kb|keyboard) _roku_keyboard ;;
            b) _roku_keypress back ;;
            l) _roku_keypress left ;;
            r) _roku_keypress right ;;
            u) _roku_keypress up ;;
            d) _roku_keypress down ;;
            pause) _roku_keypress 'play' ;;
            p) _roku_keypress 'play' ;;
            ok) _roku_keypress 'select' ;;
            *) _roku_keypress "$1" ;;
        esac
    done
}

roku() {
    if test -n "$1"; then
        _roku "$@"
    else
        while read -a cmd; do
            _roku  "${cmd[@]}"
        done
    fi
}

alias r='roku'
