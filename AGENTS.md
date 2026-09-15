# Agent Guidance

## OpenFastTrace

Run requirement tracing with `./tools/trace-requirements.sh`. It uses
OpenFastTrace and traces `doc`, `src`, and `spec`.

## Fast Validation

Use these commands after relevant changes:

```sh
./tools/trace-requirements.sh
./tools/format-lua.sh
./tools/runluacheck.sh
./tools/runtests.sh spec/unit
./tools/build-docs.sh
```

`format-lua.sh` edits Lua sources in place and also runs LuaCheck. Build and
test reports are written under the ignored `target/` directory.

## Integration Tests

Integration tests require a fully initialized Exasol database. Run only the
integration suite with its Busted profile:

```sh
EXASOL_HOST=<host> \
  EXASOL_PORT=<port> \
  EXASOL_USER=<user> \
  EXASOL_PASSWORD=<password> \
  ./tools/runtests.sh --run=itest
```

For a locally started `exasol/docker-db` container, the defaults are port
`8563`, user `sys`, and password `exasol`, so `EXASOL_HOST=localhost` is
usually sufficient. Wait until database initialization completes before
running the suite; an incomplete container closes the TLS handshake and causes
cascading integration-test failures.
