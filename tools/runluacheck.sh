#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly src_module_path="$base_dir/src"
readonly test_module_path="$base_dir/spec"

luacheck "$src_module_path" --max-line-length 120 --codes --exclude-files src/luasql/exasol/luws.lua

luacheck "$test_module_path" --max-line-length 120 --codes

luacheck "$base_dir/doc/user_guide/examples.lua" --max-line-length 75 --codes
