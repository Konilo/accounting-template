# Accounting

Exhaustive, [double-entry, plain text accounting](https://plaintextaccounting.org/What-is-Plain-Text-Accounting) of my financial life using [`hledger`](https://hledger.org/index.html).

## Disclaimer

This is a sanitized copy of my actual personal accounting repo. The banks, brokers and employer are anonymised (bank A, broker B, employer A, etc.), and the data in `src/input_data/` is fictitious: two years (2024, closed, and 2025) of made-up exports, so that every command and CI job below runs as is. Only the market prices (`src/books/prices/`) are real.

## Architecture

1. The source of truth for the transactions is `src/input_data/`, which contains the transaction history (as CSVs) and the account statements (as PDFs, not included in this template) of all my accounts. The CSVs are kept as exported, never edited.
2. The books are yearly and frozen: each year has its own folder in `src/books/` (e.g. `src/books/2025/`), built once from that year's CSVs and committed. A closed year is only rebuilt on purpose, to apply a retroactive fix, and the git diff is reviewed. Each yearly book (`YYYY/YYYY.journal`) includes:
   - `../common.journal`: the declaration of every account (with its type and a description) and commodity. The books are checked in [strict mode](https://hledger.org/hledger.html#strict-mode), so a typo in a rule or an uncategorised transaction fails loudly instead of creating a new account.
   - `../prices/YYYY/*.prices`: the daily closing prices of the commodities held that year (e.g., CW8/EUR), fetched once with [pricehist](https://pypi.org/project/pricehist/) (`src/scripts/prices.sh`).
   - `opening.journal`: the balances carried over from the previous year (`hledger close --clopen`).
   - `generated.journal`: the transactions generated from the CSVs by `src/scripts/build.sh`, with `hledger print` and tailor-made rules (`src/books/rules/`). Never edited by hand.
      - In double-entry accounting, each transaction is mapped to an input and an output account: e.g., 10€ coming out of `assets:bank-a:checking-bank-a` and going into `expenses:discretionary:presents-given`. This mapping is a core part of the logic coded in the import rules (`rules/import/`, one per account), while fixes to specific rows of the CSVs live in separate correction rules (`rules/corrections/`).
      - Transfers between my own accounts are imported from both accounts' exports and go through `assets:in-transit`, so each account carries its own bank's dates.
   - `manual.journal`: the few facts that are not in any CSV (e.g., opening balances, a lost exchange transaction).
   - `assertions.journal`: the balances read on the account statements, so that the books are checked against reality.
   - `closing.journal`: the balances closed at the end of the year.

   `src/books/all.journal` includes every year, for multi-year reports. Reports on it exclude the yearly closing/opening pairs with `not:tag:clopen`.
3. At that point, `hledger`, through its CLI, TUI, or Web interface, is ready to act as a powerful accounting engine and allows a wide array of queries and reports to be run out of the box.
4. On top of that, [Paisa](https://paisa.fyi/), which hooks on the `hledger` journal, provides a thorough dashboard. Its settings are in `src/paisa/`: Paisa reads `paisa.journal`, which renames the top-level accounts to the names Paisa expects, and `hledger.conf` leaves out the yearly closing/opening pairs.
5. Since `hledger` offers an extensive CLI, it can efficiently be leveraged by bash, Python, or any other scripting language in order to add an additional layer of logic on top of what the `hledger` CLI allows. This is helpful to code analyses that make sense for a specific person, project, or portfolio: e.g., a yearly savings rate.
6. Of course, the `hledger` CLI and the scripting that can be implemented on top of it make this system fundamentally "AI-ready".

All the recurrent commands go through [`just`](https://just.systems/): run `just` to list them.

## Setup

Clone the repo and open it in [VS Code](https://code.visualstudio.com/) (or any [VS Code](https://github.com/microsoft/vscode)-based IDE):

```sh
git clone git@github.com:Konilo/accounting-template.git
cd accounting-template
code .
```

Select "Reopen in Container" to spin up the dev container ([Docker](https://www.docker.com/) required). Dependencies and extensions are installed automatically.

The sample books are ready to use: `just check` checks them. To start your own books, replace the sample data and adapt the rest to your accounts:

1. Delete the sample years and prices (`src/books/20*/`, `src/books/prices/*/`), their `include` lines in `src/books/all.journal`, and the sample CSVs in `src/input_data/`.
2. Put your own exports in `src/input_data/`, list them with their rules in `src/scripts/build.sh`, and adapt the rules (`src/books/rules/`), the accounts and commodities (`src/books/common.journal`) and the tickers (`src/scripts/prices.sh`).
3. `just new 2025`, write your opening balances in `src/books/2025/manual.journal`, then build and check the books:

```sh
just build 2025
just prices 2025
just check
```

You can now run `hledger` commands in the terminal. For example, a balance sheet showing the balance of each asset and liability account (with an account depth of 3) at the end of each year, and an income statement summarizing the flows between accounts year by year:

```sh
just bs
just is
```

Or any `hledger` command on all the years (`-f src/books/all.journal`, adding `not:tag:clopen`) or on a single year (`-f src/books/2025/2025.journal`).

To spin up the Paisa dashboard, run this:

```sh
just paisa
```

## Yearly close protocol

At the start of each year, for the year just ended (e.g., on 2027-01-01, for 2026):

1. Download the December statements and the yearly exports (January 1 to December 31) of every account into `src/input_data/`. Exports of the same account must not overlap: `just build` refuses them.
2. `just new 2026`, then `just close 2025`: creates the 2026 book and carries the 2025 balances over into it.
3. Add the import rules and account declarations of any new account.
4. `just build 2026`, then add correction rules where needed (`rules/corrections/`), write a `manual.journal`, if necessary, and add assertions using account statements (`assertions.journal`).
5. `just prices 2026`, then `just check` until it passes.
6. Review the git diff and commit. The year is frozen.

## CI

Every pull request and every push to `main` runs `.github/workflows/ci.yml`. Each job is a `just` recipe, so it can be run locally first:

- `just fmt-lint-uv-check`: Python formatting and lint (ruff), shell scripts (shellcheck), Justfile formatting, `uv.lock` up to date. `just fmt-lint-fix` fixes what can be fixed.
- `just check`: checks the books in strict mode.
- `just rebuild`: rebuilds every derived file (generated journals, closings and openings) from the CSVs and the rules; CI fails if the result differs from what is committed. The prices are not refetched.
- `just frozen BASE`: on pull requests, fails if the transactions of a closed year (one whose `closing.journal` is not empty) changed since the base branch. A retroactive change is made on purpose by adding the `deliberate-retroactive-change` label to the pull request; the job then passes.
