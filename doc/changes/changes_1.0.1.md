# exasol-driver-lua 1.0.1, released 2026-09-15

Code name: Increased Connection Timeout

## Summary

This is a maintenance release where we increased the waiting timeout for establishing connections to 60 seconds.
The reason is that we saw in very rare occasions that a TLS handshake can take longer than the current 10 seconds and increasing the timeout allows the connection to recover.

## Bugfixes

* : Increased timeout in `Websocket.lua` to 60 seconds
* : Removed duplicate UDF script terminator `/` to fix a broken test.

## Refactoring

* Moved design and system requirements into their own subdirectory.
