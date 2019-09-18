#!/bin/bash
_f="includes.sh"
test "$(basename $0)" = "$_f" && { echo "$_f: standalone execution not allowed" && exit 1; }

fexit () {
    test "$1" = "-h" && { shift; printf "Oops: $@\n\n"; show_help; } || { printf "Oops: $@\n"; }
    exit 1
}
