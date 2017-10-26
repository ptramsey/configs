#!/bin/bash

_get_pod() {
    kubectl get pods -l app="$1" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'
}

_local_shell() {
    pod=$(_get_pod "$1")
    container="$1${2:+-$2}"
    kubectl exec -it "$pod" -c "$container" /bin/bash -i || kubectl exec -it "$pod" -c "$container" /bin/sh -i
}

receipt() {
    _local_shell "receipt"
}

receipt-test() {
    _local_shell "receipt" "test"
}

alias lcl="_local_shell"
