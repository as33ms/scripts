#!/bin/bash
f="includes.sh"
test "$(basename $0)" = "$f" && { echo "$f: standalone execution not allowed" && exit 1; }

fexit () {
    case $1 in
        -h)
            show_help
            shift
            ;;
    esac

    echo "$@"
    exit 1
}
