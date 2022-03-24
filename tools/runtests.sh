#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# This script finds and runs Lua tests, collects coverage and runs static code analysis.

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly target_dir="$base_dir/target"
readonly reports_dir="$target_dir/test-reports"
readonly luacov_dir="$target_dir/luacov-reports"

##
# Print the summary section of the code coverage report to the console
#
function print_coverage_summary {
    echo
    grep --after 500 'File\s*Hits' "$luacov_dir/luacov.report.out"
}

rm -rf "$luacov_dir"
mkdir -p "$reports_dir"
mkdir -p "$luacov_dir"

cd "$base_dir"
busted "$@"
print_coverage_summary