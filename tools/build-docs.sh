#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly target_dir="$base_dir/target/ldoc/api/"
mkdir --parents "$target_dir"
ldoc --config "$base_dir/config.ld" --dir "$target_dir" --verbose --fatalwarnings .
echo "ldoc result: $?"
