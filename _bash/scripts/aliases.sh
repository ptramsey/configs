alias open=xdg-open
if which gls >/dev/null; then
    LS=gls
else
    LS=ls
fi
alias ls="$LS --color=auto"
unset LS
