# Single entry point for the books. Run `just` to list the recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

books := "src/books"
all := books / "all.journal"

# List the recipes
recipes:
    @just --list

# Create the book for YEAR and add it to all.journal
new year:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="{{ books }}/{{ year }}"
    [ ! -e "$dir" ] || { echo "$dir already exists" >&2; exit 1; }
    mkdir -p "$dir"
    printf '; Hand-written transactions for %s: facts that are not in any CSV export.\n' {{ year }} > "$dir/manual.journal"
    printf '; Balances read on account statements, checked at the end of the day.\n' > "$dir/assertions.journal"
    : > "$dir/opening.journal"
    : > "$dir/generated.journal"
    : > "$dir/closing.journal"
    {
        echo "; Book for {{ year }}. Set LEDGER_FILE to this file to work on {{ year }} alone."
        echo
        echo "include ../common.journal"
        echo "include opening.journal"
        echo "include generated.journal"
        echo "include manual.journal"
        echo "include assertions.journal"
        echo "include closing.journal"
    } > "$dir/{{ year }}.journal"
    echo "include {{ year }}/{{ year }}.journal" >> {{ all }}
    echo "Created $dir; next: just close $(({{ year }} - 1)), just build {{ year }}"

# Generate YEAR/generated.journal from the CSV exports
build year:
    bash src/scripts/build.sh {{ year }}

# Fetch YEAR's market prices (closing prices, days held), once per year
prices year *args:
    bash src/scripts/prices.sh {{ year }} {{ args }}

# Check the books in strict mode: all years together, then each year alone
check:
    #!/usr/bin/env bash
    set -euo pipefail
    hledger -f {{ all }} check --strict
    for f in {{ books }}/[0-9][0-9][0-9][0-9]/[0-9][0-9][0-9][0-9].journal; do
        hledger -f "$f" check --strict
    done
    echo "OK"

# Rebuild every derived file from the CSVs: generated journals, closings and openings (not the prices)
rebuild:
    #!/usr/bin/env bash
    set -euo pipefail
    for dir in {{ books }}/[0-9][0-9][0-9][0-9]; do
        bash src/scripts/build.sh "$(basename "$dir")"
    done
    # Closed years only (closing.journal not empty), in order: each close feeds the next opening
    for dir in {{ books }}/[0-9][0-9][0-9][0-9]; do
        [ ! -s "$dir/closing.journal" ] || just close "$(basename "$dir")"
    done

# Fail if a closed year's transactions changed since BASE
frozen base="origin/main":
    bash src/scripts/frozen.sh {{ base }}

# Check the formatting and lint of the code, and that uv.lock is up to date
fmt-lint-uv-check:
    # format
    uv run ruff format --check src
    # lint
    uv run ruff check src
    git ls-files -z '*.sh' | xargs -0 shellcheck
    just --fmt --check --unstable
    uv lock --check

# Format and fix the lint of the code (what can be fixed)
fmt-lint-fix:
    # format
    uv run ruff format src
    # lint (safe fixes only)
    uv run ruff check --fix src
    just --fmt --unstable

# Close YEAR into YEAR/closing.journal and YEAR+1/opening.journal (clopen)
close year:
    #!/usr/bin/env bash
    set -euo pipefail
    next=$(({{ year }} + 1))
    file="{{ books }}/{{ year }}/{{ year }}.journal"
    acct=equity:opening-closing-balances
    [ -d "{{ books }}/$next" ] || { echo "Create the $next book first: just new $next" >&2; exit 1; }
    # Compute the balances without a previous closing of this year
    : > "{{ books }}/{{ year }}/closing.journal"
    hledger -f "$file" close --close -e "$next" --close-acct "$acct" > "{{ books }}/{{ year }}/closing.journal.tmp"
    hledger -f "$file" close --open -e "$next" --open-acct "$acct" > "{{ books }}/$next/opening.journal"
    mv "{{ books }}/{{ year }}/closing.journal.tmp" "{{ books }}/{{ year }}/closing.journal"
    echo "Wrote {{ books }}/{{ year }}/closing.journal and {{ books }}/$next/opening.journal"

# Yearly balances of assets and liabilities
bs *args:
    hledger -f {{ all }} bal --pretty -Y --pager no -E -H --depth 3 type:AL not:tag:clopen {{ args }}

# Yearly income statement
is *args:
    hledger -f {{ all }} is --pretty -Y --pager no not:tag:clopen {{ args }}

# Yearly investment gains (PnL) per group of investments
roi:
    #!/usr/bin/env bash
    set -euo pipefail
    for inv in 'assets:bank-b:investment-bank-b' 'assets:broker-(a|b|c)' 'assets:bank-a:savings' 'assets:broker-d'; do
        echo "== $inv"
        # the clopen exclusion must be in --inv: roi ignores other queries
        hledger -f {{ all }} roi -Y --inv "$inv not:tag:clopen" --pnl 'revenues:(interest|capital-gains)' --value=then,EUR --pretty
    done

# Open the Paisa dashboard
paisa:
    cd src/paisa && Paisa
