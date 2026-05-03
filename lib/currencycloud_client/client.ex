defmodule CurrencycloudClient.Client do
  @moduledoc """
  The primary client struct that is passed to every API function.

  A `Client` bundles:
  - The `Config` (base URL, credentials, timeouts, etc.)
  - A reference to the `Session` GenServer that manages the auth token
  - The HTTP module to use (overrideable for testing)
  - An optional `on_behalf_of` contact UUID for sub-account scoping

  ## Creating a client

  ### With an explicit supervisor (production)

      # In your Application:
      children = [
        {CurrencycloudClient.Session, config: config, name: MyApp.CCSession}
      ]

      # Then build the client:
      client = CurrencycloudClient.Client.new(config, MyApp.CCSession)

  ### Anonymous (short-lived, scripts, tests)

      {:ok, session} = CurrencycloudClient.Session.start_link(config: config)
      client = CurrencycloudClient.Client.new(config, session)

  ## Sub-account scoping (on_behalf_of)

  All mutating API functions accept an optional `on_behalf_of: contact_id`
  option. Alternatively, scope the entire client:

      sub_client = CurrencycloudClient.Client.on_behalf_of(client, contact_id)

      # All calls on sub_client are automatically scoped:
      CurrencycloudClient.API.Balances.get(sub_client, "EUR")
      CurrencycloudClient.API.Payments.create(sub_client, payment_params)
  """

  alias CurrencycloudClient.Config
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.Session

  @type t :: %__MODULE__{
          config: Config.t(),
          session: GenServer.server(),
          http_mod: module(),
          on_behalf_of: String.t() | nil
        }

  defstruct [
    :config,
    :session,
    on_behalf_of: nil,
    http_mod: CurrencycloudClient.HTTP
  ]

  @doc """
  Creates a new `Client` struct.

  ## Parameters
  - `config` – A validated `%CurrencycloudClient.Config{}`.
  - `session` – PID or registered name of a running `CurrencycloudClient.Session`.
  - `opts` – Optional: `[http_mod: MyMock]` for test overrides.
  """
  @spec new(Config.t(), GenServer.server(), keyword()) :: t()
  def new(%Config{} = config, session, opts \\ []) do
    http_mod = Keyword.get(opts, :http_mod, CurrencycloudClient.HTTP)

    %__MODULE__{
      config: config,
      session: session,
      http_mod: http_mod
    }
  end

  @doc """
  Returns a new client scoped to the given contact UUID.
  All subsequent API calls through this client will include `on_behalf_of`.

  ## Example

      sub = CurrencycloudClient.Client.on_behalf_of(client, "ce404ead-...")
      {:ok, balance} = CurrencycloudClient.API.Balances.get(sub, "EUR")
  """
  @spec on_behalf_of(t(), String.t()) :: t()
  def on_behalf_of(%__MODULE__{} = client, contact_id) when is_binary(contact_id) do
    %{client | on_behalf_of: contact_id}
  end

  @doc """
  Clears any `on_behalf_of` scoping, returning a house-account client.
  """
  @spec clear_on_behalf_of(t()) :: t()
  def clear_on_behalf_of(%__MODULE__{} = client) do
    %{client | on_behalf_of: nil}
  end

  @doc """
  Fetches the current auth token from the Session.
  Returns `{:ok, token}` or `{:error, %AuthenticationError{}}`.
  """
  @spec get_token(t()) :: {:ok, String.t()} | {:error, Error.t()}
  def get_token(%__MODULE__{session: session}) do
    Session.get_token(session)
  end

  @doc """
  Builds the full URL for the given API path.

      CurrencycloudClient.Client.url(client, "/v2/balances/EUR")
      #=> "https://devapi.currencycloud.com/v2/balances/EUR"
  """
  @spec url(t(), String.t()) :: String.t()
  def url(%__MODULE__{config: config}, path) do
    config.base_url <> path
  end

  @doc """
  Merges the `on_behalf_of` field into a params map (if set on the client).
  """
  @spec merge_on_behalf_of(t(), map()) :: map()
  def merge_on_behalf_of(%__MODULE__{on_behalf_of: nil}, params), do: params

  def merge_on_behalf_of(%__MODULE__{on_behalf_of: obo}, params) when is_map(params) do
    Map.put_new(params, "on_behalf_of", obo)
  end

  @doc """
  Makes a GET request using the client's session token and HTTP module.
  Handles token expiry by delegating to `Session.get_token/1`.
  """
  @spec get(t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get(%__MODULE__{} = client, path, params \\ %{}) do
    with {:ok, token} <- get_token(client) do
      full_url = url(client, path)
      full_params = merge_on_behalf_of(client, params)
      client.http_mod.get(full_url, full_params, token, client.config)
    end
  end

  @doc """
  Makes a POST request using the client's session token and HTTP module.
  """
  @spec post(t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def post(%__MODULE__{} = client, path, params \\ %{}) do
    with {:ok, token} <- get_token(client) do
      full_url = url(client, path)
      full_params = merge_on_behalf_of(client, params)
      client.http_mod.post_form_authenticated(full_url, full_params, token, client.config)
    end
  end

  @doc """
  Makes a DELETE request using the client's session token and HTTP module.
  """
  @spec delete(t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def delete(%__MODULE__{} = client, path, params \\ %{}) do
    with {:ok, token} <- get_token(client) do
      full_url = url(client, path)
      full_params = merge_on_behalf_of(client, params)
      client.http_mod.delete(full_url, full_params, token, client.config)
    end
  end

  @doc """
  Makes a PUT request using the client's session token and HTTP module.
  """
  @spec put(t(), String.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def put(%__MODULE__{} = client, path, params \\ %{}) do
    with {:ok, token} <- get_token(client) do
      full_url = url(client, path)
      full_params = merge_on_behalf_of(client, params)
      client.http_mod.put(full_url, full_params, token, client.config)
    end
  end
end
