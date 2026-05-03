# CurrencycloudClient

[![Hex.pm](https://img.shields.io/hexpm/v/currencycloud_client.svg)](https://hex.pm/packages/currencycloud_client)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/currencycloud_client)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Production-grade Elixir / Hex client for the [Currencycloud v2 API](https://developer.currencycloud.com).

## Features

- **Complete API coverage** — all 14 API groups: Accounts, Balances, Beneficiaries, Contacts, Conversions, Funding, Payments, Payers, Rates, Reference, Reporting, Transactions, Transfers, Withdrawal Accounts.
- **Token lifecycle management** — `Session` GenServer proactively refreshes tokens before expiry; auto-retries on 401.
- **Exponential backoff with full jitter** — `RetryStrategy` retries on 429 and 5xx.
- **Typed error structs** — `AuthenticationError`, `BadRequestError`, `TooManyRequestsError`, `NetworkError`, etc.
- **Sub-account scoping** — first-class `on_behalf_of` support as a per-call param or client-level scope.
- **Webhook verification** — HMAC-SHA256 signature verification with replay-attack protection.
- **Telemetry integration** — `:telemetry` events for every request, token refresh, and retry.
- **NimbleOptions config validation** — clear errors at startup, not at runtime.
- **OTP-native** — supervised `Session` GenServer.

## Installation

```elixir
def deps do
  [{:currencycloud_client, "~> 0.1"}]
end
```

## Quick start

```elixir
config = CurrencycloudClient.Config.new!(
  environment: :demo,
  login_id: System.fetch_env!("CC_LOGIN_ID"),
  api_key: System.fetch_env!("CC_API_KEY")
)

{:ok, session} = CurrencycloudClient.Session.start_link(config: config)
client = CurrencycloudClient.Client.new(config, session)

{:ok, balance} = CurrencycloudClient.API.Balances.get(client, "EUR")
IO.puts("EUR: #{balance["amount"]}")
```

See the full documentation at [hexdocs.pm/currencycloud_client](https://hexdocs.pm/currencycloud_client).
