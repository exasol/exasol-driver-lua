#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# This script builds all design diagrams

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly diagrams_dir="$base_dir/doc/model/diagrams"
readonly output_dir="$base_dir/doc/images/generated"

echo "Deleting diagrams from $output_dir..."

rm "$output_dir"/*.svg

expected_diagram_count=$(find "$diagrams_dir" -name "*.plantuml" | wc --lines)
readonly expected_diagram_count

echo "Building $expected_diagram_count diagrams..."
plantuml -tsvg -output "$output_dir" -failonerror -failonwarn -failfast2 "$diagrams_dir/**/*.plantuml"

actual_diagram_count=$(find "$output_dir" -name "*.svg" | wc --lines)
readonly actual_diagram_count

if [ "$expected_diagram_count" -ne "$actual_diagram_count" ]; then
    echo "ERROR: Expected $expected_diagram_count diagrams but $actual_diagram_count where generated"
    exit 1
fi

echo "All $actual_diagram_count diagrams where built successfully in $output_dir."
