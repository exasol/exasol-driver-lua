#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly src_module_path="$base_dir/src"
readonly test_module_path="$base_dir/spec"

# Don't format third party code
GLOBIGNORE="$src_module_path/luws.lua"
lua-format --config="$base_dir/.lua-format" --verbose -i -- "$src_module_path"/*.lua "$test_module_path"/*.lua "$test_module_path"/*/*.lua
unset GLOBIGNORE

"$base_dir/tools/runluacheck.sh"
