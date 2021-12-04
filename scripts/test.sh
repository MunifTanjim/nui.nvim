#!/usr/bin/env sh

test_dir="${1:-"nui"}"

nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/${test_dir}/ { minimal_init = 'tests/minimal_init.vim' }"
