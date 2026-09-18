# exasol-driver-lua 1.0.1, released 2026-09-18

Code name: Increased Connection Timeout

## Summary

This is a maintenance release where we increased the waiting timeout for establishing connections to 60 seconds.
The reason is that we saw in very rare occasions that a TLS handshake can take longer than the current 10 seconds and increasing the timeout allows the connection to recover.

We also fixed a broken integration test and improved the diagnostics around it.

## Bugfixes

* #105: Increased timeout in `Websocket.lua` to 60 seconds
* #105: Fixed a broken test. 

## Refactoring

* 105: Moved design and system requirements into their own subdirectory.
