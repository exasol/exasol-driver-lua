# GH-100 Add TLS Certificate Fingerprint Pinning

## Goal

Allow a Lua caller to authenticate an Exasol server TLS certificate using an expected SHA-256 certificate fingerprint, without requiring a CA file, trust store, or access to the driver's internal LuWS socket. A failed pin check must stop the connection before the WebSocket upgrade, Exasol login command, or credentials are sent.

## Scope

In scope:

* Add an opt-in connection property for pinning the TLS peer certificate to a SHA-256 fingerprint.
* Define its canonical representation, accepted normalizations, validation, and errors.
* Verify the peer certificate within the driver immediately after a successful TLS handshake and before `luws` upgrades the connection to WebSocket.
* Document the property and add unit, handshake-level, and TLS integration coverage.

Out of scope:

* Changing the defaults or semantics of `tls_verify`, `tls_protocol`, or `tls_options`.
* Exposing LuaSec sockets, certificate objects, or generic certificate APIs to driver callers.
* Reading certificates, CA files, or trust stores from the filesystem.
* Changing Exasol Virtual Schema Lua; it will consume this capability in its
  related GH-76 work.

## Design References

* [System Requirements](../system_requirements.md)
* [Design](../design.md)
* [Connection sequence](../model/diagrams/sequence/seq_environment_connect.plantuml)
* [WebSocket request/response sequence](../model/diagrams/sequence/seq_websocket_request_response.plantuml)
* [Connection properties](../../src/luasql/exasol/ConnectionProperties.lua)
* [WebSocket connection](../../src/luasql/exasol/Websocket.lua)
* [Bundled LuWS](../../src/luasql/exasol/luws.lua)

## Strategy

Introduce `fingerprint` as an optional connection property. Its canonical form will be 64 hexadecimal SHA-256 digits; the requirements update must state whether lower-case input and colon-separated hex pairs are accepted, then normalize accepted input to one canonical form.

Malformed configuration is rejected by `ConnectionProperties:create()` before any network connection is opened.

Pass the normalized pin through `Websocket` to LuWS. After `ssl.wrap()` and a successful `dohandshake()`, LuWS obtains the peer certificate, exports its DER encoding, calculates SHA-256 with the already-supported Lua/OpenSSL stack, and compares normalized values in constant-time if the available API supports it.

It closes the TLS socket and returns a dedicated mismatch error on failure; only a successful check reaches `wsupgrade()`. The implementation must first confirm the LuaSec/luaossl APIs and UDF compatibility for certificate DER export and SHA-256, without adding dependencies.

The current repository has no `doc/design/quality_requirements.md` or `doc/changesets/README.md`, despite the current OFT workflow expecting them. Until those repository-level documents are introduced, the verification below uses the enforced local gates in the developer guide and scripts.

## Task List

- [x] Create and checkout a new Git branch `feat/100-add-tls-certificate-fingerprint-pinning`.

### Requirements And Design

- [x] Add a user-facing `req~tls-certificate-fingerprint-pinning~1` and separate scenarios for absent pin, malformed pin, matching pin, and mismatching pin in `doc/system_requirements.md`; preserve the existing `req~luasql-environment-connect~1` and connect the new requirement to the LuaSQL API feature.
- [x] Specify `fingerprint`: 64 hexadecimal SHA-256 digits as the canonical form, any permitted case/separator normalization, and distinct safe diagnostics for invalid configuration, unavailable peer certificate/DER data, and mismatch. State that diagnostics exclude credentials and certificate contents.
- [x] Stop and ask the user for a review of the system requirements.
- [x] Add `dsn~tls-certificate-fingerprint-pinning~1` to `doc/design.md` and update the connection/WebSocket sequence diagrams to show validation before socket creation and pin verification after TLS handshake but before `wsupgrade()` and login; trace each runtime design item to exactly one new scenario or use forwarding where appropriate.
- [x] Review the class diagram; no update is needed because the selected implementation retains the existing `ConnectionProperties` → `Websocket` → LuWS flow.
- [x] Stop and ask the user for a review of the design.

### Implementation

- [x] Confirm and encapsulate the LuaSec/luaossl peer-certificate, DER-export, SHA-256, and constant-time-comparison APIs supported by the project’s pinned dependencies and Exasol UDF runtime; retain the existing dependency set.
- [x] Extend `ConnectionProperties` with documented property access, normalization, and pre-connect validation using dedicated stable error identifiers.
- [x] Forward the normalized property through `Websocket.connect()` to `wsopen()` without exposing socket internals to callers.
- [x] Modify bundled `luws.lua` to obtain and hash the peer certificate only after a successful TLS handshake; on verification failure close and clear the TLS socket, return a safe dedicated error, and do not call `wsupgrade()`.
- [x] Preserve connection behavior byte-for-byte when the pin is absent, including the existing TLS options and retry/error handling.

### Verification

- [x] Add unit tests for property absence, canonical pins, each accepted normalization, invalid length/characters/type, and safe malformed-pin diagnostics.
- [x] Add isolated tests for DER fingerprint calculation and both matching and mismatching comparisons, including failures to obtain/export the peer certificate.
- [x] Add handshake-level tests with a controllable TLS/LuWS seam showing that a mismatch closes the socket and prevents `wsupgrade()`, `send_login_command()`, and `send_login_credentials()`.
- [x] Add TLS integration coverage against a controlled certificate for both a matching pin and a mismatch; assert the mismatch fails before WebSocket upgrade/login and that no credentials appear in the error.
- [x] Keep existing TLS option tests, UDF amalgamation tests, and the full integration suite green.
- [x] Run `./tools/runtests.sh`, `./tools/runluacheck.sh`, `./tools/trace-requirements.sh`, and `./tools/build-diagrams.sh`.

### Update User Documentation

- [x] Update `doc/user_guide/user_guide.md`, `ConnectionProperties` API documentation, and the connection-properties example with the property’s canonical format, accepted normalization, opt-in behavior, and secure error contract; do not include a real certificate fingerprint.
- [x] Update `README.md` with the concise TLS-pinning capability in its feature summary.

## Version and Changelog Update

- [x] Include the GH-100 feature in the unreleased `1.0.0` release.
- [x] Add the GH-100 entry to `doc/changes/changes_1.0.0.md`.
