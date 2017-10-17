#!/bin/bash

_get_pod() {
    kubectl get pods -l app="$1" -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}'
}

_local_shell() {
    kubectl exec -it $(_get_pod "$1") -c "$2" /bin/bash -i
}

receipt() {
    _local_shell "receipt" "receipt"
}

receipt-test() {
    _local_shell "receipt" "receipt-test"
}

alias lcl="_local_shell"
