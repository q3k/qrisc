ORConf23 VLIW RISC Demo
===

Simple 3-stage pipelined VLIW RISC CPU with no explicit instruction set - all
based on packed tagged unions.

To run, get bluespec+python3 and start run.sh. Fibonacci sequence will be calculated, look at vop1 state of the Decoded structure when executing Add instructions.

If you have Nix(OS), you can just ./run.sh and deps will be automatically fetched.

