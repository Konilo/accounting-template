#!/bin/bash
# Fetch the market prices of YEAR into src/books/prices/YEAR/, one file per
# commodity held during YEAR, covering the days it was held. Closing prices
# from Yahoo Finance via pricehist (the default type, adjclose, is revised
# retroactively, which would change the valuation of closed years).
#
# Prices are fetched once per year and committed. Existing files are kept
# unless --refetch is given.
#
# Usage: src/scripts/prices.sh YEAR [--refetch]

set -euo pipefail

year="${1:?usage: src/scripts/prices.sh YEAR [--refetch]}"
refetch="${2:-}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
books="$root/src/books"
dir="$books/prices/$year"

# Commodity | Yahoo ticker | symbol in the journal | decimals
tickers=(
    'CW8|CW8.PA|"CW8"|4'
    'DCAM|DCAM.PA|DCAM|4'
    'BTC|BTC-EUR|BTC|2'
    'USDC|USDC-EUR|USDC|6'
)

# Days held in YEAR, per commodity: "COMMODITY FIRST LAST"
held="$(hledger -f "$books/all.journal" reg type:A not:cur:EUR not:tag:clopen -H -O csv \
    -e "$((year + 1))-01-01" | python3 -c '
import csv, sys, collections
year = sys.argv[1]
start, end = f"{year}-01-01", f"{year}-12-31"
bal = collections.defaultdict(float)   # running quantity per commodity
first, last = {}, {}
for r in csv.DictReader(sys.stdin):
    for part in r["amount"].split(", "):
        if part in ("", "0"): continue
        q, com = part.split(" ", 1)
        com = com.strip("\"")
        d = r["date"]
        if d >= start and bal[com] > 1e-12:
            first.setdefault(com, start)   # held when the year starts
        bal[com] += float(q)
        if d >= start:
            if bal[com] > 1e-12: first.setdefault(com, d)
            last[com] = d
for com, q in bal.items():
    if q > 1e-12:
        first.setdefault(com, start); last[com] = end
for com in sorted(first):
    print(com, first[com], last[com])
' "$year")"

[ -n "$held" ] || {
    echo "No commodity held in $year"
    exit 0
}
mkdir -p "$dir"
while read -r com first last; do
    line="$(printf '%s\n' "${tickers[@]}" | grep "^$com|" || true)"
    [ -n "$line" ] || {
        echo "No ticker for $com, add it to src/scripts/prices.sh" >&2
        exit 1
    }
    IFS='|' read -r _ ticker symbol decimals <<<"$line"
    file="$dir/$(tr '[:upper:]' '[:lower:]' <<<"$com").prices"
    if [ -e "$file" ] && [ "$refetch" != "--refetch" ]; then
        echo "Kept ${file#"$root"/} (use --refetch to replace it)"
        continue
    fi
    uv run --project "$root" pricehist fetch -o ledger -t close -s "$first" -e "$last" \
        --fmt-base "$symbol" --quantize "$decimals" yahoo "$ticker" >"$file.tmp"
    mv "$file.tmp" "$file"
    echo "Wrote ${file#"$root"/}: $com $first..$last, $(wc -l <"$file") prices"
done <<<"$held"

# Include the year's prices in its book (first run only)
journal="$books/$year/$year.journal"
include="include ../prices/$year/*.prices"
if ! grep -qxF "$include" "$journal"; then
    sed -i "s|^include ../common.journal$|&\n$include|" "$journal"
    echo "Added the prices include to ${journal#"$root"/}"
fi
