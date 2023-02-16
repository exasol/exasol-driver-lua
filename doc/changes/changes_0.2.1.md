# exasol-driver-lua 0.2.1, released 2023-02-16

Code name: Repeated CI tests

## Summary

Repeated CI tests were disabled in 0.2.0 because they ran abnormally long. We re-enabled these tests and made them faster.

When running integration tests with `luarocks test` or `busted`, the environment variable `EXASOL_HOST` now has a default value `localhost` to make running tests more convenient.
If you run local tests, the Exasol DB is most likely set up to forward the default database port to the localhost anyway.

Additionally, coverage checks are now restricted to selected busted configurations. For example, it does not make sense to run with coverage on repeated tests.

Integration test now succeeds with TLS 1.3 in addition to TLS 1.2 (version 8.18.0)

## Bugfixes

* #56: Sped up repeated CI tests