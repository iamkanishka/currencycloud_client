# Changelog

## 0.1.0 (2026-04-29)

### Added
- Initial release
- Complete Currencycloud v2 API coverage (14 API groups, 60+ endpoints)
- `Session` GenServer with proactive token refresh and auto-reauth on 401
- Typed error structs with `to_diagnostic/1` for rich logging
- Exponential backoff with full jitter via `RetryStrategy`
- `on_behalf_of` sub-account scoping at client level and per-call
- HMAC-SHA256 webhook signature verification with replay-attack protection
- `:telemetry` integration for requests, retries, and token refreshes
- `NimbleOptions`-validated configuration
- `MockHTTP` + `Factory` for test isolation
