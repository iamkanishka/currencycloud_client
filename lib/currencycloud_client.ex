defmodule CurrencycloudClient do
  @moduledoc """
  Production-grade Elixir client for the Currencycloud v2 API.

  ## Quick start

      config = CurrencycloudClient.Config.new!(
        environment: :demo,
        login_id: System.fetch_env!("CC_LOGIN_ID"),
        api_key: System.fetch_env!("CC_API_KEY")
      )

      {:ok, session} = CurrencycloudClient.Session.start_link(config: config)
      client = CurrencycloudClient.Client.new(config, session)

      {:ok, balance} = CurrencycloudClient.API.Balances.get(client, "EUR")

  ## Modules

  - `CurrencycloudClient.Config` — Build and validate configuration.
  - `CurrencycloudClient.Client` — The client struct passed to every API call.
  - `CurrencycloudClient.Session` — GenServer managing token lifecycle.
  - `CurrencycloudClient.Error` — Typed error structs with diagnostics.
  - `CurrencycloudClient.Webhooks` — HMAC signature verification.
  - `CurrencycloudClient.Telemetry` — Observability/metrics integration.
  - `CurrencycloudClient.RetryStrategy` — Exponential backoff with jitter.
  """

  @doc """
  Returns a pre-built client using the library-managed session.
  Only available if `manage_session: true` is in your application config.
  """
  @spec default_client() :: CurrencycloudClient.Client.t()
  def default_client do
    unless Process.whereis(CurrencycloudClient.DefaultSession) do
      raise "CurrencycloudClient.DefaultSession is not running. " <>
              "Set manage_session: true in config, or start your own Session."
    end

    config = CurrencycloudClient.Config.from_application_env()
    CurrencycloudClient.Client.new(config, CurrencycloudClient.DefaultSession)
  end

  @doc """
  Wraps a function in an on_behalf_of scope for a contact UUID.

  All API calls made inside `fun` will be scoped to `contact_id`.

  ## Example

      CurrencycloudClient.on_behalf_of(client, contact_id, fn sub ->
        CurrencycloudClient.API.Balances.get(sub, "EUR")
      end)
  """
  @spec on_behalf_of(
          CurrencycloudClient.Client.t(),
          String.t(),
          (CurrencycloudClient.Client.t() -> result)
        ) :: result
        when result: any()
  def on_behalf_of(%CurrencycloudClient.Client{} = client, contact_id, fun)
      when is_binary(contact_id) and is_function(fun, 1) do
    sub = CurrencycloudClient.Client.on_behalf_of(client, contact_id)
    fun.(sub)
  end
end
