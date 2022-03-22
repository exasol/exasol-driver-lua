#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# This script finds and runs Lua unit tests, collects coverage and runs static code analysis.

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir

readonly exit_ok=0
readonly exit_software=2
readonly target_dir="$base_dir/target"
readonly reports_dir="$target_dir/test-reports"
readonly luacov_dir="$target_dir/luacov-reports"

function create_target_directories {
    mkdir -p "$reports_dir"
    mkdir -p "$luacov_dir"
}

##
# Run the unit tests and collect code coverage.
#
# Return error status in case there were failures.
#
function run_tests {
    cd "$base_dir"
    busted
}

##
# Print the summary section of the code coverage report to the console
#
function print_coverage_summary {
    echo
    grep --after 500 'File\s*Hits' "$luacov_dir/luacov.report.out"
}

create_target_directories
run_tests \
&& print_coverage_summary \
|| exit "$exit_software"

exit "$exit_ok"