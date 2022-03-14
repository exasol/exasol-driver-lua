#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# This script builds all design diagrams

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly diagrams_dir="$base_dir/doc/model/diagrams"

expected_diagram_count=$(find "$diagrams_dir" -name "*.plantuml" | wc --lines)
readonly expected_diagram_count

plantuml -tpng -failonerror -failonwarn -failfast2 -verbose "$diagrams_dir/**/*.plantuml"

actual_diagram_count=$(find "$diagrams_dir" -name "*.png" | wc --lines)
readonly actual_diagram_count

if [ "$expected_diagram_count" -ne "$actual_diagram_count" ]; then
    echo "Expected $expected_diagram_count diagrams but $actual_diagram_count where generated"
    exit 1
fi

echo "All $actual_diagram_count diagrams where generated"
