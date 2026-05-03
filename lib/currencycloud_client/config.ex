defmodule CurrencycloudClient.Config do
  @moduledoc """
  Configuration for the Currencycloud client.

  ## Application config (config.exs)

      config :currencycloud_client,
        environment: :demo,
        login_id: "your@email.com",
        api_key: "your-api-key",
        timeout: 30_000,
        pool_size: 10,
        max_retries: 5,
        telemetry_prefix: [:currencycloud_client]

  ## Runtime config (recommended for secrets)

      CurrencycloudClient.Config.new!(
        environment: :production,
        login_id: System.fetch_env!("CC_LOGIN_ID"),
        api_key: System.fetch_env!("CC_API_KEY")
      )

  ## Options

  - `:environment` – `:demo` or `:production`. Defaults to `:demo`.
  - `:login_id` – Your Currencycloud login email (required).
  - `:api_key` – Your Currencycloud API key (required).
  - `:timeout` – HTTP request timeout in ms. Defaults to `30_000`.
  - `:connect_timeout` – TCP connect timeout in ms. Defaults to `5_000`.
  - `:pool_size` – HTTP connection pool size. Defaults to `10`.
  - `:max_retries` – Max retry attempts on 429/5xx. Defaults to `5`.
  - `:retry_base_delay` – Base delay in ms for exponential backoff. Defaults to `500`.
  - `:retry_max_delay` – Maximum delay cap in ms. Defaults to `30_000`.
  - `:token_refresh_buffer` – Seconds before expiry to proactively refresh. Defaults to `120`.
  - `:telemetry_prefix` – Telemetry event name prefix. Defaults to `[:currencycloud_client]`.
  - `:user_agent` – HTTP User-Agent header. Defaults to `"currencycloud_client/0.1.0 (Elixir)"`.
  """

  @schema NimbleOptions.new!(
            environment: [
              type: {:in, [:demo, :production]},
              default: :demo,
              doc: "API environment: :demo or :production"
            ],
            login_id: [
              type: :string,
              required: true,
              doc: "Currencycloud login ID (usually your email)"
            ],
            api_key: [
              type: :string,
              required: true,
              doc: "Currencycloud API key"
            ],
            timeout: [
              type: :pos_integer,
              default: 30_000,
              doc: "HTTP request timeout in milliseconds"
            ],
            connect_timeout: [
              type: :pos_integer,
              default: 5_000,
              doc: "TCP connect timeout in milliseconds"
            ],
            pool_size: [
              type: :pos_integer,
              default: 10,
              doc: "HTTP connection pool size"
            ],
            max_retries: [
              type: :non_neg_integer,
              default: 5,
              doc: "Maximum retry attempts on 429 or 5xx responses"
            ],
            retry_base_delay: [
              type: :pos_integer,
              default: 500,
              doc: "Base delay in ms for exponential backoff"
            ],
            retry_max_delay: [
              type: :pos_integer,
              default: 30_000,
              doc: "Maximum delay cap in ms for exponential backoff"
            ],
            token_refresh_buffer: [
              type: :pos_integer,
              default: 120,
              doc: "Seconds before token expiry to proactively refresh"
            ],
            telemetry_prefix: [
              type: {:list, :atom},
              default: [:currencycloud_client],
              doc: "Telemetry event name prefix"
            ],
            user_agent: [
              type: :string,
              default: "currencycloud_client/0.1.0 (Elixir)",
              doc: "HTTP User-Agent header value"
            ]
          )

  @type environment :: :demo | :production

  @type t :: %__MODULE__{
          environment: environment(),
          login_id: String.t(),
          api_key: String.t(),
          timeout: pos_integer(),
          connect_timeout: pos_integer(),
          pool_size: pos_integer(),
          max_retries: non_neg_integer(),
          retry_base_delay: pos_integer(),
          retry_max_delay: pos_integer(),
          token_refresh_buffer: pos_integer(),
          telemetry_prefix: [atom()],
          user_agent: String.t(),
          base_url: String.t(),
          finch_name: atom() | nil
        }

  @enforce_keys [:environment, :login_id, :api_key]
  defstruct environment: :demo,
            login_id: nil,
            api_key: nil,
            finch_name: nil,
            timeout: 30_000,
            connect_timeout: 5_000,
            pool_size: 10,
            max_retries: 5,
            retry_base_delay: 500,
            retry_max_delay: 30_000,
            token_refresh_buffer: 120,
            telemetry_prefix: [:currencycloud_client],
            user_agent: "currencycloud_client/0.1.0 (Elixir)",
            base_url: nil

  @base_urls %{
    demo: "https://devapi.currencycloud.com",
    production: "https://api.currencycloud.com"
  }

  @doc """
  Creates a validated `Config` struct. Raises `NimbleOptions.ValidationError` on invalid input.

  ## Example

      config = CurrencycloudClient.Config.new!(
        environment: :demo,
        login_id: "user@example.com",
        api_key: "abc123"
      )
  """
  @spec new!(keyword()) :: t()
  def new!(opts) do
    opts = NimbleOptions.validate!(opts, @schema)
    env = opts[:environment]

    base = struct!(__MODULE__, opts)
    Map.put(base, :base_url, @base_urls[env])
  end

  @doc """
  Creates a `Config` from application environment, merging any runtime overrides.

  Reads from `Application.get_env(:currencycloud_client, ...)`.
  """
  @spec from_application_env(keyword()) :: t()
  def from_application_env(overrides \\ []) do
    base = Application.get_all_env(:currencycloud_client)
    merged = Keyword.merge(base, overrides)
    new!(merged)
  end

  @doc "Returns the base URL for the configured environment."
  @spec base_url(t()) :: String.t()
  def base_url(%__MODULE__{base_url: url}), do: url

  @doc "Returns the NimbleOptions schema (for documentation/introspection)."
  @spec schema() :: NimbleOptions.t()
  def schema, do: @schema
end
