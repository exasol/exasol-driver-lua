# exasol-driver-lua 0.2.1, released 2025-01-27

Code name: Upgrade to Exasol 8.29.6

## Summary

This release updates integration tests to additionally use Exasol version 8.27.0.

When running integration tests with `luarocks test` or `busted`, the environment variable `EXASOL_HOST` now has a default value `localhost` to make running tests more convenient.
If you run local tests, the Exasol DB is most likely set up to forward the default database port to the localhost anyway.

Additionally, coverage checks are now restricted to selected busted configurations. For example, it does not make sense to run with coverage on repeated tests.

Integration test now succeeds with TLS 1.3 in addition to TLS 1.2 (version 8.18.0)

## Tests

* #56: Sped up repeated CI tests
* #78: Added tests with Exasol 8
* #91: Fixed failing tests with Exasol 8
