#!/usr/bin/env sh

set -eu

test_dir="${1:-"nui"}"

luacov_dir="$(dirname $(luarocks which luacov 2>/dev/null | head -1))"

if test -n "${luacov_dir}"; then
  rm -f luacov.*.out
  export LUA_PATH=";;${luacov_dir}/?.lua"
fi

nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/${test_dir}/ { minimal_init = 'tests/minimal_init.vim'; sequential = true }"

if test -n "${luacov_dir}"; then
  luacov

  echo
  tail -n +$(($(cat luacov.report.out | grep -n "^Summary$" | cut -d":" -f1) - 1)) luacov.report.out
fi
