#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly src_module_path="$base_dir/src"
readonly test_module_path="$base_dir/spec"

# Don't format third party code
GLOBIGNORE="$src_module_path/luasql/exasol/luws.lua"

lua-format --config="$base_dir/.lua-format" --verbose --in-place -- \
  "$src_module_path"/luasql/*.lua \
  "$src_module_path"/luasql/exasol/*.lua \
  "$test_module_path"/*.lua \
  "$test_module_path"/*/*.lua

lua-format --config="$base_dir/.lua-format" --column-limit=75 --verbose --in-place "$base_dir"/doc/user_guide/examples.lua

unset GLOBIGNORE

"$base_dir/tools/runluacheck.sh"
