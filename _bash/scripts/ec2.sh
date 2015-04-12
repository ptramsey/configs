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

_SSH_ARGSPEC=$(_get_ssh_args)

# Print usage information: same as for 'ssh', except that the ec2 instance name or id takes the place
# of the hostname
_ec2_usage() {
    ssh 2>&1 | sed 's#^usage: ssh#usage: ec2#g' | sed 's#\[user@\]hostname#[user@]instance-name#' >&2
}

_EC2_WAIT_TIME=2

# Look up an instance by tag or id.  Fail if more than one matching instance is found.
_ec2_get_instance() {
    local instance_name="$1"
    local -a instances

    IFS=$'\n' read -d '' -r -a instances < <(ec2-lookup "$instance_name")

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

# Wait for a successful ssh connection
_wait_for_ssh() {
    for i in {0..10}; do
        sleep $_EC2_WAIT_TIME
        ssh -q "${options[@]}" true && break
    done
    ssh "${options[@]}" true
}

# SSH workalike.  Finds the instance, turns it on iff it's powered off, then connects
# to it.
ec2() {
    test -z "$*" && { _ec2_usage; return; }

    local options=()
    local starting=
    local username=${DEFAULT_EC2_USERNAME:-$(whoami)}

    local OPTIND
    while getopts "$_SSH_ARGSPEC" opt; do
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
                echo >&2 "Instance started.  Trying to connect..."
                _wait_for_ssh "${options[@]}" || return
            fi

            ssh "${options[@]}" "$@"
            return
            ;;
        stopped)
            aws ec2 start-instances --instance-ids $instance_id >/dev/null
            ;&
        pending)
            test -n "$starting" || echo >&2 -n "Starting $instance_name..."
            starting=1

            sleep $_EC2_WAIT_TIME
            echo >&2 -n "."
            ;;
        *)
            echo >&2 "Instance is in state '$state'; can't connect"
            return 1
            ;;
        esac
    done
}

# Set an instance's Name tag
ec2-setname() {
    if test $# -ne 2 -o ${1:0:2} != "i-"; then
        echo >&2 "Usage: ${FUNCNAME[0]} INSTANCE_ID NAME";
        return 1;
    fi
    aws ec2 create-tags --resources "$1" --tags Key=Name,Value="$2"
}

# Look up instances by tag or id and output useful information
ec2-lookup() {
    local query="Reservations[*].Instances[*].[InstanceId,\
                                               InstanceType,\
                                               Placement.AvailabilityZone,\
                                               State.Name,\
                                               PublicDnsName]"
    local instance_name="$1"
    local by_id=

    if test "${instance_name:0:2}" = "i-"; then
        # Lookup by instance id
        by_id=$(aws ec2 describe-instances --instance-ids "$instance_name" \
                                           --output text --query "$query")
        echo "$by_id"
    fi

    if test -z "$by_id"; then
        # Lookup by tag
        aws ec2 describe-instances --filters Name=tag:Name,Values="$instance_name" \
                                   --output text --query "$query"
    fi
}
