#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p ../build/vcs
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
  -f files.f -top tb_top -o ../build/vcs/simv -l ../build/vcs/compile.log
../build/vcs/simv +N_RANDOM=100 "$@" -l ../build/vcs/run.log
