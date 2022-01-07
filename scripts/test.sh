#!/usr/bin/env sh

test_dir="${1:-"nui"}"

luacov_dir="$(dirname $(luarocks which luacov 2>/dev/null | head -1))"

if test -n "${luacov_dir}"; then
  rm -f luacov.*.out
  export LUA_PATH=";;${luacov_dir}/?.lua"
fi

nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/${test_dir}/ { minimal_init = 'tests/minimal_init.vim' }"

if test -n "${luacov_dir}"; then
  luacov
fi
