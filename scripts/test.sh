#!/usr/bin/env bash

set -euo pipefail

declare -r plugins_dir="./.tests/site/pack/deps/start"
declare -r module="nui"

declare test_scope="${module}"

while [[ $# -gt 0 ]]; do
  case "${1}" in
    --clean)
      shift
      echo "[test] cleaning up environment"
      rm -rf "${plugins_dir}"
      echo "[test] envionment cleaned"
      ;;
    *)
      if [[ "${test_scope}" == "${module}" ]] && [[ "${1}" == "${module}/"* ]]; then
        test_scope="${1}"
      fi
      shift
      ;;
  esac
done

function setup_environment() {
  echo
  echo "[test] setting up environment"
  echo

  if [[ ! -d "${plugins_dir}" ]]; then
    mkdir -p "${plugins_dir}"
  fi

  if [[ ! -d "${plugins_dir}/plenary.nvim" ]]; then
    echo "[plugins] plenary.nvim: installing..."
    git clone https://github.com/nvim-lua/plenary.nvim "${plugins_dir}/plenary.nvim"
    # commit 9069d14a120cadb4f6825f76821533f2babcab92 broke luacov
    # issue: https://github.com/nvim-lua/plenary.nvim/issues/353
    local -r plenary_353_patch="$(pwd)/scripts/plenary-353.patch"
    git -C "${plugins_dir}/plenary.nvim" apply "${plenary_353_patch}"
    echo "[plugins] plenary.nvim: installed"
    echo
  fi

  echo "[test] environment ready"
  echo
}

function luacov_start() {
  luacov_dir="$(dirname "$(luarocks which luacov 2>/dev/null | head -1)")"
  if [[ "${luacov_dir}" == "." ]]; then
    luacov_dir=""
  fi

  if test -n "${luacov_dir}"; then
    rm -f luacov.*.out
    export LUA_PATH=";;${luacov_dir}/?.lua"
  fi
}

function luacov_end() {
  if test -n "${luacov_dir}"; then
    if test -f "luacov.stats.out"; then
      luacov

      echo
      tail -n +$(($(grep -n "^Summary$" luacov.report.out | cut -d":" -f1) - 1)) luacov.report.out
    fi
  fi
}

setup_environment

luacov_start

declare test_logs=""

if [[ -d "./tests/${test_scope}/" ]]; then
  test_logs=$(nvim --headless --noplugin -u tests/init.lua -c "lua require('plenary.test_harness').test_directory('./tests/${test_scope}/', { minimal_init = 'tests/init.lua', sequential = true })")
elif [[ -f "./tests/${test_scope}_spec.lua" ]]; then
  test_logs=$(nvim --headless --noplugin -u tests/init.lua -c "lua require('plenary.busted').run('./tests/${test_scope}_spec.lua')")
fi

echo "${test_logs}"

luacov_end

if echo "${test_logs}" | grep --quiet "stack traceback"; then
  {
    echo ""
    echo "FOUND STACK TRACEBACK IN TEST LOGS"
    echo ""
  } >&2
  exit 1
fi
