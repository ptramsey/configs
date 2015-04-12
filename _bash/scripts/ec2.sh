#!/bin/bash
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

# ec2.sh - Implements a wrapper around ssh, which automatically looks up/starts an
#          instance by name before connecting to it.

# Parses the openssh client's usage information to produce an option string for 'getopt'
_get_ssh_args() {
    set $(ssh 2>&1 | tr -d '[]')
    shift 2

    echo -n $1 | tr -d -
    shift

    while test -n "$1"; do
        echo "$1" | egrep -q '^-' && echo -n "$1:" | tr -d -
        shift
    done

    echo
}

_ssh_argspec=$(_get_ssh_args)

# Print usage information: same as for 'ssh', except that the ec2 instance name or id takes the place
# of the hostname
_ec2_usage() {
    ssh 2>&1 | sed 's#^usage: ssh#usage: ec2#g' | sed 's#\[user@\]hostname#[user@]instance-name#' >&2
}

# Fetch instance information from the ec2 api.  Fail if more than one matching instance is found.
_ec2_get_instance() {
    local query="Reservations[*].Instances[*].[InstanceId,\
                                               InstanceType,\
                                               Placement.AvailabilityZone,\
                                               State.Name,\
                                               PublicDnsName]"
    local instance_name="$1"
    local instances

    IFS=$'\n' read -d '' -r -a instances < <(
        aws ec2 describe-instances --filters Name=tag:Name,Values="$instance_name" \
                                   --output text --query "$query")

    if test ${#instances[@]} -eq 0 && egrep -q '^i-' <<< "$instance_name"; then
        # Maybe it was an instance id, not a tag!
        IFS=$'\n' read -d '' -r -a instances < <(
            aws ec2 describe-instances --instance-ids "$instance_name" \
                                       --output text --query "$query")
    fi

    if test ${#instances[@]} -eq 0; then
        echo >&2 "No instances could be found by that name."
        return 1
    elif test ${#instances[@]} -gt 1; then
        echo >&2 "More than one instance exists by that name:"
        printf >&2 '%s\n' "${instances[@]}"
        return 1
    fi

    echo "${instances[0]}"
}

_wait_for_ssh() {
    for i in {0..10}; do
        sleep $wait_time
        ssh -q "${options[@]}" true && break
    done
    if test $? -ne 0; then
        echo >&2 "Timed out waiting to connect"
        return 1
    fi
}

# SSH workalike.  Finds the instance, turns it on iff it's powered off, then connects
# to it.
ec2() {
    test -z "$*" && { _ec2_usage; return; }

    local options=()
    local starting=
    local username=${DEFAULT_EC2_USERNAME:-$(whoami)}
    local wait_time=2

    local OPTIND
    while getopts "$_ssh_argspec" opt; do
        test $opt = "?" && { _ec2_usage; return; }
        options+=("$1")
        test -n "$OPTARG" && options+=("$OPTARG")
    done
    shift $((OPTIND-1))

    local instance_name="$1"
    if grep -q '@' <<< "$instance_name"; then
        username=$(cut -d@ -f1 <<< "$instance_name")
        instance_name=$(cut -d@ -f 2- <<< "$instance_name")
    fi
    shift

    while true; do
        local instance instance_id size az state hostname
        instance=$(_ec2_get_instance "$instance_name") || return
        read instance_id size az state hostname <<< "$instance"

        case $state in
        running)
            printf '\r%100s\r'

            options+=("${username}@${hostname}")

            if test -n "$starting"; then
                echo "Instance started.  Trying to connect..."
                _wait_for_ssh "${options[@]}" || return
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
