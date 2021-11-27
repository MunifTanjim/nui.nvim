#!/usr/bin/env sh

expected_stylua_version="0.11.2"
stylua_version="$(stylua --version | cut -d' ' -f2)"

if test "${stylua_version}" != "${expected_stylua_version}"; then
  echo "expected stylua v${expected_stylua_version}, found v${stylua_version}"
  exit 1
fi

stylua --color always --check lua/
