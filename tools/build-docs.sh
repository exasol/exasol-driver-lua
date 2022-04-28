#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly src_module_path="$base_dir/src"
readonly target_dir="$base_dir/target/ldoc"
mkdir --parents "$target_dir"


ldoc --config "$base_dir/.ldoc.ld" --dir "$target_dir" --output "index" --project "LuaSQL driver for Exasol" --title "Reference" \
  --format "markdown" --package "." \
  --verbose \
  --fatalwarnings \
  "$src_module_path"

  #
