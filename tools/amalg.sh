#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir
readonly target_dir="$base_dir/target"

mkdir -p "$target_dir"

rockspec_file=$(find "$base_dir" -maxdepth 1 -name "*.rockspec")
readonly rockspec_file

print_luarocks_modules=$(cat <<-END_OF_SCRIPT
local function load_rockspec(path)
    local env = {}
    local rockspec_function = assert(loadfile(path, "t", env))
    rockspec_function()
    return env
end

local function print_module_names(rockspec)
    for module_name, _ in pairs(rockspec.build.modules) do
        print(module_name)
    end
end

if #arg ~= 1 then
    error("Expected rockspec path as argument but got "..#arg.." arguments")
end
local rockspec = load_rockspec(arg[1])
print_module_names(rockspec)
END_OF_SCRIPT
)

echo "Reading $rockspec_file"
modules=$(lua -e "$print_luarocks_modules" - "$rockspec_file" < /dev/null)

echo "Modules: $modules"

module_names=$(echo "$modules" | tr '\n' ' ')
echo "Found modules: $module_names"
amalg.lua --debug --output "$target_dir/exasol-driver-amalg.lua" --script="$base_dir/doc/user_guide/examples.lua" ${module_names[@]}



