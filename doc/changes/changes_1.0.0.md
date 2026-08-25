# exasol-driver-lua 1.0.0, released 2026-08-??

Code name: TSL Certificate Fingerprint Pinning

## Summary

This release adds optional TLS certificate fingerprint pinning for database connections.

This release updates all dependencies on top of 0.2.1. We also decided to increase the version number of the driver to 1.0.0, since all basic features are now available.

We also now pin the Ubuntu version to 24.04 in the CI build.

Breaking change: Support for Exasol 7.x has been removed.

## Features

* #100: Add TLS certificate fingerprint pinning.

## Refactoring

* #97: Updated dependencies on 0.2.1
