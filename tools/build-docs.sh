#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly target_dir="$base_dir/target/ldoc"
mkdir --parents "$target_dir"

#cd "$src_module_path"
ldoc --config "$base_dir/config.ld" --verbose --fatalwarnings .

echo "ldoc result: $?"
