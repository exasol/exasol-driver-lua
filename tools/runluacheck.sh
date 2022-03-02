#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly src_module_path="$base_dir/src"
readonly test_module_path="$base_dir/test"

echo
echo "Running static code analysis"
echo
luacheck "$src_module_path" "$test_module_path" --codes --ignore 111 # --ignore 112
