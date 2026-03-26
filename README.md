# Accounting

Exhaustive, [double-entry, plain text accounting](https://plaintextaccounting.org/What-is-Plain-Text-Accounting) of my financial life using [`hledger`](https://hledger.org/index.html).

## Disclaimer

This is a sanitized copy of my actual personal accounting repo.

## Architecture

1. The source of truth for the transactions is `src/input_data/` which contains transaction history (as CSVs) & account statements (as PDFs) for all my accounts.
2. The (idempotent) `src/setup/setup.sh` script processes those files into a unified, ready-to-analyze `hledger` journal. The script essentially does the following things:
   - It initializes the journal using `src/hledger/hledger_empty.journal` which contains basic `hledger` configuration (account declarations, opening balances, amount formats, etc.).
   - It imports the transaction history of each account using tailor-made rules made to accurately interpret the nature of each transaction and integrate it in the journal (`*.rules` files in `src/hledger/rules/`).
      - In double-entry accounting, each transaction is mapped to an input and an ouput account: e.g., 10€ coming out of `Assets:bank-a:checking` and going into `Expenses:discretionary:presents-given`. This mapping is a core part of the logic coded in `*.rules` files.
      - Assertions are inserted to make sure the amounts correspond to the reality inscribed in the account statements.
   - It retrieves the daily close prices for the pairs that appear in my portfolio (e.g., CW8/EUR).
3. At that point, `hledger`, through its CLI, TUI, or Web interface, is ready to act as a powerful accounting engine and allows a wide array of queries and reports to be run out of the box.
4. On top of that, [Paisa](https://paisa.fyi/), which hooks on the `hledger` journal, provides a thorough dashboard. Its settings are in `src/paisa/`.
5. Since the `hledger` offers an extensive CLI, it can efficiently be leveraged by bash, Python, or any other scripting language in order to add an additional layer of logic on top of what the `heldger` CLI allows. This is helpful to code analysis that make sense for a specific person, project, or portfolio.
6. Of course, the `hledger` CLI and the scripting that can be implemented on top of it make this system fundamentally "AI-ready".

## Setup

Clone the repo and open it in [VS Code](https://code.visualstudio.com/) (or any [VS Code](https://github.com/microsoft/vscode)-based IDE):

```sh
git clone git@github.com:Konilo/accounting.git
cd accouting
code .
```

Select "Reopen in Container" to spin up the dev container ([Docker](https://www.docker.com/) required). Dependencies and extensions are installed automatically.

Take over `input_data/`, `rules/` and `src/setup/setup.sh` to adapt them to your needs, and then run the (idempotent) setup script:

```sh
/workspaces/accounting/src/setup/setup.sh
```

You can now run `hledger` commands in the terminal. For example, you can make a balance sheet showing the balance of each Asset & Liability account (with an account depth of 3) at the end of each year:

```sh
hledger bal --pager no --pretty -Y -E -H --depth 3 acct:Assets Liabili
```

Or an income statement summarizing the flows between accounts year by year:

```sh
hledger is --pretty --pager no -Y
```

To spin up the Paisa dashboard, run this:

```sh
cd /workspaces/accounting/src/paisa && Paisa
```
