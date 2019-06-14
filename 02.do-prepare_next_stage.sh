#!/bin/bash
failure_exit() {
    echo "$@" && exit 1
}

cf=$USER/.hardening.conf
test -f $cf && echo "OK" || failure_exit "Missing file: $cf. Did you run 01.do-run_1st_on_droplet.sh?"

source $cf
export $(cut -d= -f1 $cf) || failure_exit "Unable to export saved config from 01.do-run_1st_on_droplet.sh."

for cmd in "${!NEXT_COMMANDS[@]}"; do
    echo "Running command: $cmd"
    $($cmd)
done

