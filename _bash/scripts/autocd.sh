# Copyright (c) Patrick Taylor Ramsey, All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer. Redistributions in binary
# form must reproduce the above copyright notice, this list of conditions and
# the following disclaimer in the documentation and/or other materials provided
# with the distribution. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
# NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Implements a forwards and reverse directory history on top of bash, along 
# with a version of autocd that respects it.  Commands defined here:
#
# u[p] [N] - jump up N levels (1 if omitted) in the directory hierarchy
# b[ack] [n] - go back N directories (1 if omitted)
# f[orwards] [n] - go forward N directories (1 if omitted)
# cd [DIR|~|-] - behaves like cd, but stores a directory history
# [DIR|~] - Automatically cd to DIR (or ~) if DIR is not already the name
#           of a command
#
# Autocd works using bash's DEBUG faux-signal trap (which executes before
# every command is run) to detect if the user is attempting to autocd, and,
# if so, to block stderr so the failing command doesn't echo anything.  If
# we are doing an automatic cd, then the actual chdir is performed (and 
# stderr restored) from $PROMT_COMMAND, which executes before the next
# prompt is shown.

pushd() {
    command pushd "$@" && unset _forwards
}

# Jump up N levels in the directory hierarchy.
up() {
    test -z "$1" && set 1
    if test "$1" -gt 0; then
        up $(( $1 - 1 )) "../$2"
    else
        pushd "$2" >/dev/null
    fi
}

# Jump back N directories.
back() {
    test -z "$1" && set 1
    if test "$1" -gt 0; then
        oldcwd=$(pwd)
        popd >/dev/null && _forwards+=("$oldcwd") && back $(($1 - 1))
    fi
}

# Jump forwards N directories.
forwards() {
    test -z "$1" && set 1
    if test "$1" -gt 0; then
        if test  "${#_forwards[@]}" -eq 0; then
            echo "Forward history empty." >&2
            return 1
        fi

        len="${#_forwards[@]}"
        command pushd "${_forwards[$len-1]}" >/dev/null &&
            unset _forwards[$len-1] &&
            forwards $(($1 - 1))
    fi
}

cd() {
    case $1 in
        -) test -n "$_forwards" && forwards || back ;;
        "") pushd ~ >/dev/null ;;
        *) pushd "$1" >/dev/null ;;
    esac
}

alias b=back
alias u=up
alias f=forwards

# Detect if the user is attempting to auto-cd
prep_autocd() {
    test "$1" = '~' && set "${HOME}"

    # If the command doesn't exist, but a directory by that name does,
    if ! command -v "$1" >/dev/null && test -d "$1" && test -z "$_autocd_dir"; then
        echo -e "\033[01;32mautocd:\033[0m $(readlink -f "$1")";

        # Store the fact that we're in an autocd,
        _autocd_dir="$1"

        # and hide the 'command not found' message when bash attempts to execute
        # the directory name.
        exec {_autocd_stderr}>&2;
        exec 2>/dev/null;
    fi
}

autocd() {
    # If we are automatically changing directory, do so now
    test -n "$_autocd_dir" && cd "$_autocd_dir"
    unset _autocd_dir

    # unblock stderr
    test -n "$_autocd_stderr" && exec 2>&$_autocd_stderr-
    unset _autocd_stderr
}

# $BASH_COMMAND is the actual literal command the user entered (including backslashes
# and quotes), so there's no way to know what the actual command name is without
# handing it off to another instance of bash to parse any escaped or quoted spaces.
parse_argv() {
    argv="$1"
    bash -c 'split() { while test -n "$1"; do echo "$1"; shift; done; }; '"split $argv"
}

autocd_hook() {
    prep_autocd "$(parse_argv "$*" | head -n1)"
}

trap 'autocd_hook "$BASH_COMMAND"' DEBUG
PROMPT_COMMAND="autocd;${PROMPT_COMMAND}"
