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
    test "$1" = '~' && set "${HOME}"

    if ! command -v "$1" >/dev/null && test -d "$1" && test -z "$_autocd_dir"; then
        echo -e "\033[01;32mautocd:\033[0m $(readlink -f "$1")";

        _autocd_dir="$1"

        # Hide output from unsuccessful command
        exec {_autocd_stderr}>&2;
        exec 2>/dev/null;
    fi
}

autocd() {
    if test -n "$_autocd_dir"; then
        # Unblock stderr
        test -n "$_autocd_stderr" && exec 2>&$_autocd_stderr-;
        
        cd "$_autocd_dir";

        unset _autocd_stderr;
        unset _autocd_dir
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
