up() {
    [ -z "$1" ] && level=1 || level="$1"
    if [ "$level" -gt 0 ]; then
        up $(( level - 1 )) "../$2"
    else
        pushd "$2" >/dev/null
    fi
}

cd() {
    case $1 in
        -) test -n "$_forwards" && forwards || back ;;
        "") pushd ~ >/dev/null && unset _forwards ;;
        *) pushd "$1" >/dev/null && unset _forwards;;
    esac
}

back() {
    test -z "$1" && set 1
    if test "$1" -gt 0; then
        oldcwd=$(pwd)
        popd >/dev/null && _forwards+=("$oldcwd") && back $(($1 - 1))
    fi
}

forwards() {
    test -z "$1" && set 1
    if test "$1" -gt 0; then
        if test  "${#_forwards[@]}" -eq 0; then
            echo "Forward history empty." >&2
            return 1
        fi
        pushd "${_forwards[-1]}" >/dev/null && unset _forwards[-1] && forwards $(($1 - 1))
    fi
}

alias b=back
alias u=up
alias f=forwards

precmd() {
    command -v "$1" >/dev/null || ! test -d "$1" || test -n "$_stderr_temp" && return 0;
    echo -e "\033[01;32mautocd:\033[0m $(readlink -f "$1")";
    cd "$1";
    exec {_stderr_temp}>&2;
    exec 2>/dev/null;
}

errcmd() {
    test -n "$_stderr_temp" && exec 2>&$_stderr_temp-;
    unset _stderr_temp;
}

trap 'precmd $BASH_COMMAND' DEBUG
trap 'errcmd $BASH_COMMAND' ERR
