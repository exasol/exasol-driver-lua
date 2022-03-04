#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly src_module_path="$base_dir/src"
readonly test_module_path="$base_dir/test"

luacheck "$src_module_path" --codes --exclude-files src/luws.lua

# (W111) setting non-standard global variable TEST
# (W112) mutating non-standard global variable TEST
# (W212) unused argument self
luacheck "$test_module_path" --codes --ignore 111 --ignore 112 --ignore 212
