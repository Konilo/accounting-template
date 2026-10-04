#!/bin/bash
# Check that the closed years did not change since BASE (a git ref): their
# transactions (hledger print). A year is closed when its closing.journal is not
# empty in BASE, so closing a new year is not a change to a closed year.
#
# Compares what the books say, not the files: an account description edited in
# common.journal changes no transaction and passes, an account renamed fails.
# Prints the differences and exits 3 if there are any; any other non-zero
# exit is an error (e.g. a journal hledger can't read), not a change.
#
# Usage: src/scripts/frozen.sh BASE

set -euo pipefail

base="${1:?usage: src/scripts/frozen.sh BASE}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'git -C "$root" worktree remove --force "$tmp/base" 2>/dev/null || true; rm -rf "$tmp"' EXIT

git -C "$root" worktree add --quiet --detach "$tmp/base" "$base"

# Years whose closing.journal is not empty, in the BASE checkout
years=()
for f in "$tmp/base"/src/books/[0-9][0-9][0-9][0-9]/closing.journal; do
    [ -s "$f" ] && years+=("$(basename "$(dirname "$f")")")
done
[ ${#years[@]} -gt 0 ] || {
    echo "No closed year in $base"
    exit 0
}

# What the books of a checkout say about a closed year
fingerprint() {
    local dir="$1" year="$2"
    hledger -f "$dir/src/books/$year/$year.journal" print -x -I
}

changed=0
for year in "${years[@]}"; do
    # Files rather than <(...), so that an hledger error stops the script
    fingerprint "$tmp/base" "$year" >"$tmp/$year.base"
    fingerprint "$root" "$year" >"$tmp/$year.head"
    if ! diff -u --label "$year ($base)" --label "$year (HEAD)" "$tmp/$year.base" "$tmp/$year.head"; then
        changed=3
    fi
done

if [ "$changed" -eq 0 ]; then
    echo "Closed years unchanged: ${years[*]}"
fi
exit "$changed"
