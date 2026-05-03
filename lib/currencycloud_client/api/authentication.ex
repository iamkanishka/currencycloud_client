defmodule CurrencycloudClient.API.Authentication do
  @moduledoc """
  Authentication API — login and logout.

  In normal usage you do **not** call these directly. The `Session` GenServer
  manages token lifecycle automatically. These functions are exposed for cases
  where you need direct control (e.g. one-shot scripts).

  ## Endpoints

  - `POST /v2/authenticate/api` – Login
  - `POST /v2/authenticate/close_session` – Logout
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Config
  alias CurrencycloudClient.Error

  @login_path "/v2/authenticate/api"
  @logout_path "/v2/authenticate/close_session"

  @doc """
  Authenticates with the Currencycloud API and returns a raw auth token.

  You typically don't need this — `Session` calls it automatically. Use it
  only for one-shot scripts or unusual token management flows.

  ## Example

      config = CurrencycloudClient.Config.new!(
        environment: :demo,
        login_id: "user@example.com",
        api_key: "abc123"
      )
      {:ok, %{"auth_token" => token}} = CurrencycloudClient.API.Authentication.login(config)
  """
  @spec login(Config.t()) :: {:ok, map()} | {:error, Error.t()}
  def login(%Config{} = config) do
    http_mod = CurrencycloudClient.HTTP
    url = config.base_url <> @login_path
    params = %{"login_id" => config.login_id, "api_key" => config.api_key}
    http_mod.post_form_unauthenticated(url, params, config)
  end

  @doc """
  Logs out the current session, invalidating the auth token.

  ## Example

      :ok = CurrencycloudClient.API.Authentication.logout(client)
  """
  @spec logout(Client.t()) :: :ok | {:error, Error.t()}
  def logout(%Client{} = client) do
    case Client.post(client, @logout_path, %{}) do
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end
end
