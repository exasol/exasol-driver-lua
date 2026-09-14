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
