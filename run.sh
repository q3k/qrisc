#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bluespec python3

set -e -x

# Generate Verilog source for inspection
bsc -verilog -g mkTb ORConf.bsv

# Generate IRAM
python3 mkram.py

# Run simulation.
# Calculates fibonnaci sequence. Look at `Execute:` lines and `vopq` to see the
# argument to Add instructions.
bsc -sim -g mkTb ORConf.bsv
bsc -sim -e mkTb
exec ./a.out
