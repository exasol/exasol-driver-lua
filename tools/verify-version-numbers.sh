#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

# shellcheck disable=SC2046 # word splitting is OK here
lua "$base_dir/tools/verify-version-numbers.lua" $(find "$base_dir" -maxdepth 1 -name "*.rockspec")
