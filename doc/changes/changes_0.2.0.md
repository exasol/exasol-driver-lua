# exasol-driver-lua 0.2.0, released 2022-10-21

Code name: Run inside an Exasol UDF

## Summary

In this release we added support for using `exasol-driver-lua` inside an Exasol [user defined functions (UDF)](https://docs.exasol.com/db/latest/database_concepts/udf_scripts.htm). See the [user guide](../user_guide/user_guide.md#using-exasol-driver-lua-in-an-exasol-udf) for detailed instructions.

## Features

* #23: Added support for running inside an Exasol UDF

## Documentation

+ #54: Added dependency list

## Refactoring

* #77: Upgrade to `exaerror` 2.0.1

## Bugfixes

* #82: Fixed broken links and a small documentation error (`let` instead of `local`).