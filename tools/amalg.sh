#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

base_dir="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"
readonly base_dir
readonly target_dir="$base_dir/target"

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
readonly print_luarocks_modules

echo "Reading modules from $rockspec_file..."
modules=$(lua - "$rockspec_file" <<< "$print_luarocks_modules")
readonly modules
module_names=$(echo "$modules" | tr '\n' ' ')
readonly module_names
echo "Found modules: $module_names"

mkdir -p "$target_dir"

readonly new_lua_path="$base_dir/src/?.lua;$LUA_PATH"
readonly output_file="$target_dir/exasol-driver-amalg.lua"
LUA_PATH="$new_lua_path" amalg.lua --debug --output "$output_file" $module_names

ls -alh $output_file