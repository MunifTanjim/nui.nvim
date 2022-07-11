#!/usr/bin/env bash

set -euo pipefail

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --clean)
      shift
      echo "[test] cleaning up environment"
      rm -rf ./.testcache
      echo "[test] envionment cleaned"
      ;;
    *)
      shift
      ;;
  esac
done

function setup_environment() {
  echo
  echo "[test] setting up environment"
  echo

  local plugins_dir="./.testcache/plugins"
  if [[ ! -d "${plugins_dir}" ]]; then
    mkdir -p "${plugins_dir}"
  fi

  if [[ ! -d "${plugins_dir}/plenary.nvim" ]]; then
    echo "[plugins] plenary.nvim: installing..."
    git clone https://github.com/nvim-lua/plenary.nvim "${plugins_dir}/plenary.nvim"
    # this commit broke luacov
    git -C "${plugins_dir}/plenary.nvim" revert --no-commit 9069d14a120cadb4f6825f76821533f2babcab92
    echo "[plugins] plenary.nvim: installed"
    echo
  fi

  echo "[test] environment ready"
  echo
}

setup_environment

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
