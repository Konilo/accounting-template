#!/bin/bash

# https://stackoverflow.com/a/19622569
trap 'exit' ERR

#############################################
# REPRODUCIBLE SETUP FOR THIS ACCOUNTING REPO
#############################################

# NB: chmod +x /workspaces/accounting/setup.sh
# may be needed

#############################################
# 1) REINITIALIZATION
#############################################

echo "Reinitializating..."

# Use a copy of the preexisting empty journal as the new main journal (overwriting)
# It contains the right opening balances needed for reconciliation
cp /workspaces/accounting/src/hledger/hledger_empty.journal /workspaces/accounting/src/hledger/hledger.journal

# Enable the bash option needed for ** (which is enabled in zsh by default but not in bash)
shopt -s globstar

# Delete the .latest files
rm -f /workspaces/accounting/src/input_data/**/.latest*

# Re-create price files (needed for include statements), from scratch
cd /workspaces/accounting/src/hledger/prices
rm -f *
touch cw8.prices
touch dcam.prices
touch cl2.prices
touch btc.prices
touch usdc.prices

#############################################
# 2) IMPORT BANK A CHECKING
#############################################

# Go to the dir of the corresponding CSVs
cd "/workspaces/accounting/src/input_data/Bank A/CSV History"

# Import them using the corresponding rule
# Make sure that the end of line sequence of the CSVs is LF, not CRLF (convert
# them if not)
hledger import \
    bank_a_checking_2023.csv \
    bank_a_checking_2024.csv \
    bank_a_checking_2025.csv \
    --rules /workspaces/accounting/src/hledger/rules/bank_a__checking.rules

# Add an assertion to constantly check that we keep our peg to this reliable
# balance value on this date throughout future changes brought to the journal
sed -i '/2024-12-31 EXAMPLE TX 1/{n;s/-100.00 EUR$/-100.00 EUR = 1000.00 EUR/}' /workspaces/accounting/src/hledger/hledger.journal

# Add one more assertion based on another account statement
sed -i '/2025-12-30 VIREMENT VERS KONILO ZIO/{n;s/-100.00 EUR$/-100.00 EUR = 900.00 EUR/}' /workspaces/accounting/src/hledger/hledger.journal

sed -i '/2025-01-06 VIREMENT INTERNE/{n;n;s/-500.00 EUR$/-500.00 EUR = 0 EUR/}' /workspaces/accounting/src/hledger/hledger.journal

# Try the assertion
hledger check

#############################################
# 3) IMPORT BANK A SAVINGS 1
#############################################

hledger import \
    bank_a_savings_1.csv \
    --rules /workspaces/accounting/src/hledger/rules/bank_a__savings_1.rules

# Assertion with the end of 2025 balance from the acct statement
sed -i 's/  50.00 EUR/  50.00 EUR = 1000.00 EUR/' /workspaces/accounting/src/hledger/hledger.journal
hledger check

#############################################
# 4) IMPORT BANK A SAVINGS 3
#############################################

hledger import \
    bank_a_savings_3.csv \
    --rules /workspaces/accounting/src/hledger/rules/bank_a__savings_3.rules

# Assertion with the end of 2025 balance from the acct statement
sed -i 's/  1.00 EUR/  1.00 EUR = 100.00 EUR/' /workspaces/accounting/src/hledger/hledger.journal
hledger check

#############################################
# 5) IMPORT SWILE MEAL VOUCHERS
#############################################

# Go to the right dir
cd "/workspaces/accounting/src/input_data/Swile"

hledger import swile-data-2025-12-30.csv --rules /workspaces/accounting/src/hledger/rules/swile__meal_vouchers.rules

sed -i '/2025-12-29 (EXAMPLE STORE|2025-12-29|-10.00|:r1qt:)/{n;s/-10.00 EUR$/-10.00 EUR = 100.00 EUR/}' /workspaces/accounting/src/hledger/hledger.journal
hledger check

#############################################
# 6) IMPORT BANK B CHECKING
#############################################

# Go to the right dir
cd "/workspaces/accounting/src/input_data/Bank B/CSV History/Checking"

hledger import bank_b_checking.csv --rules /workspaces/accounting/src/hledger/rules/bank_b__checking.rules

sed -i '/2024-08-30 (REF_001)/{n;n;s/ 1000.00 EUR$/ 1000.00 EUR = 1000.00 EUR/}' /workspaces/accounting/src/hledger/hledger.journal
hledger check

sed -i '/2025-11-03 VIR S\/ PEA REF_002/{n;s/ -500.00 EUR$/ -500.00 EUR = 0 EUR/}' /workspaces/accounting/src/hledger/hledger.journal
hledger check

#############################################
# 7) IMPORT BANK B INVESTMENT
#############################################

# Go to the right dir
cd "/workspaces/accounting/src/input_data/Bank B/CSV History/Investment/"

hledger import bank_b_investment.csv --rules /workspaces/accounting/src/hledger/rules/bank_b__investment.rules

#############################################
# 8) IMPORT BROKER B TRADES
#############################################

# Go to the right dir
cd "/workspaces/accounting/src/input_data/Broker B/Trade History"

hledger import broker_b_trades.csv --rules /workspaces/accounting/src/hledger/rules/broker_b__trades.rules

sed -i '/2024-03-19 EXAMPLE TX 2/{n;n;s/ 100.00 EUR$/ 100.00 EUR = 0 EUR/}' /workspaces/accounting/src/hledger/hledger.journal

#############################################
# 9) IMPORT BROKER C TRADES
#############################################

# Go to the right dir
cd "/workspaces/accounting/src/input_data/Broker C/Trade History"

hledger import broker_c_trades.csv --rules /workspaces/accounting/src/hledger/rules/broker_c__trades.rules

#############################################
# 10) IMPORT BROKER A TRADES
#############################################

# Go to the right dir
cd "/workspaces/accounting/src/input_data/Broker A/Trade History"

hledger import broker_a_trades.csv --rules /workspaces/accounting/src/hledger/rules/broker_a__trades.rules

# Convert USDT to USDC in the imported transaction, cf. the other broker_a tx
sed -i 's/USDT/USDC/g' /workspaces/accounting/src/hledger/hledger.journal

#############################################
# 11) IMPORT PRICES
#############################################

# https://hledger.org/prices.html#pricehist

# CW8
echo "Fetching CW8 prices..."
uv run pricehist fetch -o ledger -s 2024-04-23 -e 2025-09-29 yahoo CW8.PA >/workspaces/accounting/src/hledger/prices/cw8.prices
sed -i -e 's/CW8\.PA/"CW8"/g' /workspaces/accounting/src/hledger/prices/cw8.prices

# DCAM
echo "Fetching DCAM prices..."
uv run pricehist fetch -o ledger -s 2025-03-19 -e 2025-12-31 yahoo DCAM.PA >/workspaces/accounting/src/hledger/prices/dcam.prices
sed -i -e 's/DCAM\.PA/DCAM/g' /workspaces/accounting/src/hledger/prices/dcam.prices

# CL2
echo "Fetching CL2 prices..."
uv run pricehist fetch -o ledger -s 2025-08-29 -e 2025-12-31 yahoo CL2.PA >/workspaces/accounting/src/hledger/prices/cl2.prices
sed -i -e 's/CL2\.PA/"CL2"/g' /workspaces/accounting/src/hledger/prices/cl2.prices

# BTC
echo "Fetching BTC prices..."
uv run pricehist fetch -o ledger -s 2024-02-01 -e 2025-12-31 yahoo BTC-EUR >/workspaces/accounting/src/hledger/prices/btc.prices
sed -i -e 's/BTC-EUR/BTC/g' /workspaces/accounting/src/hledger/prices/btc.prices

# BTC
echo "Fetching USDC prices..."
uv run pricehist fetch -o ledger -s 2024-04-03 -e 2025-12-31 yahoo USDC-EUR >/workspaces/accounting/src/hledger/prices/usdc.prices
sed -i -e 's/USDC-EUR/USDC/g' /workspaces/accounting/src/hledger/prices/usdc.prices

#############################################
# 12) FINAL CHECKS
#############################################

hledger check

# Make sure no unknown accounts remain
hledger print unknown
