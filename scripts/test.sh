#!/usr/bin/env sh

nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedDirectory tests/nui/ { minimal_init = 'tests/minimal_init.vim' }"
