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

# Implements a wrapper around ssh, which automatically looks up/starts an
# instance by name before connecting to it.

_get_ssh_args() {
    set $(ssh 2>&1 | tr -d '[]')
    shift 2

    echo -n $1 | tr -d - | sed 's/\(.\)/\1,/g'
    shift

    while test -n "$1"; do
        echo "$1" | egrep -q '^-' && echo -n "$1:," | tr -d -
        shift
    done
}

_ssh_argspec=$(_get_ssh_args)

_ec2_usage() {
    ssh 2>&1 | sed 's#^usage: ssh#usage: ec2#g' | sed 's#\[user@\]hostname#[user@]instance-name#' >&2
}

ec2() {
    options=()
    query='Reservations[*].Instances[*].[InstanceId,State.Name,PublicDnsName]'
    starting=
    username=$(whoami)
    wait_time=2

    test -z "$*" && { _ec2_usage; return 1; }

    parsed_opts=$(getopt -o "$_ssh_argspec" -- "$@")
    test $? -ne 0 && { _ec2_usage; return 1; }

    eval set -- "$parsed_opts"
    while test "$1" != "--"; do
        options+=("$1")
        shift
    done
    shift

    instance_name="$1"
    if echo "$instance_name" | grep -q '@'; then
        username=$(echo "$instance_name" | cut -d@ -f 1)
        instance_name=$(echo "$instance_name" | cut -d@ -f 2-)
    fi
    shift

    while true; do
        exec {ec2}< <(aws ec2 describe-instances --filters Name=tag:Name,Values="$instance_name" \
                                                 --output text \
                                                 --query "$query")
        read instance_id state hostname <&$ec2

        if read <&$ec2; then
            echo "More than one instance exists by that name:"
            echo -n "$instance_id "
            echo -n "$(echo $REPLY | awk '{print $1;}') "
            while read instance_id state hostname <&$ec2; do
                echo -n "$instance_id "
            done
            echo
            return 1
        fi

        exec {ec2}<&-

        case $state in
        running)
            printf '\r%100s\r'

            options+=("${username}@${hostname}")
            if test -n "$starting"; then
                echo "Instance started.  Trying to connect..."
                for i in {0..10}; do
                    sleep $wait_time
                    ssh -q "${options[@]}" true && break
                done
                if test $? -ne 0; then
                    echo "Timed out waiting to connect"
                    return 1
                fi
            fi

            ssh "${options[@]}" "$@"
            break
            ;;
        stopped)
            aws ec2 start-instances --instance-ids $instance_id >/dev/null
            echo -n "Starting $instance_name..."
            starting=1
            ;&
        pending)
            sleep $wait_time
            echo -n "."
            ;;
        *)
            echo "Instance is in state $state; can't connect"
            return 1
            ;;
        esac
    done
}
