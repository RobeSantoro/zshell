#!/bin/bash

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: ./prepend.sh [files...] \"Prefix String\""
    echo ""
    echo "Arguments:"
    echo "  [files...]      The files to rename (e.g., *.webp)"
    echo "  \"Prefix String\" The string to add to the start of the filenames"
    echo ""
    echo "Example:"
    echo "  ./prepend.sh *.webp \"IMG_\""
    exit 0
fi

args=("$@")
count=${#args[@]}
last_idx=$((count - 1))

if [[ $count -lt 2 ]]; then
    echo "Error: Not enough arguments provided."
    echo "Try './prepend.sh --help' for usage."
    exit 1
fi

prefix="${args[$last_idx]}"

for ((i=0; i<last_idx; i++)); do
    mv "${args[$i]}" "${prefix}${args[$i]}"
done
