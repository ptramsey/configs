_kirby=("<('-'<)" "(^'-'^)" "(>'-')>" "(v'-'v)")
PROMPT_COMMAND="let \"_i_=(_i_+1) % 4\" || :; ${PROMPT_COMMAND}"
PS1="${PS1}\${_kirby[\$_i_]} "
