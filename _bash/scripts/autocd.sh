pushd() {
    command pushd "$@" && unset _forwards
}

up() {
    [ -z "$1" ] && level=1 || level="$1"
    if [ "$level" -gt 0 ]; then
        up $(( level - 1 )) "../$2"
    else
        pushd "$2" >/dev/null
    fi
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
        command pushd "${_forwards[-1]}" >/dev/null && unset _forwards[-1] && forwards $(($1 - 1))
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

prep_autocd() {
    test "$1" = '~' && dir="${HOME}" || dir="$1"
    command -v "$dir" >/dev/null || ! test -d "$dir" || test -n "$_stderr_temp" && return 0;
    echo -e "\033[01;32mautocd:\033[0m $(readlink -f "$dir")";
    exec {_stderr_temp}>&2;
    exec 2>/dev/null;
}

autocd() {
    if test -n "$_stderr_temp"; then
        exec 2>&$_stderr_temp-;
        cd "$dir";
        unset _stderr_temp;
    fi
}

debug_hook() {
    prep_autocd "$@"
}

err_hook() {
    autocd "$@"
}

trap 'debug_hook $BASH_COMMAND' DEBUG
trap 'err_hook $BASH_COMMAND' ERR
