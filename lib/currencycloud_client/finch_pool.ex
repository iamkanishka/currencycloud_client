defmodule CurrencycloudClient.FinchPool do
  @moduledoc """
  Supervised Finch HTTP connection pool for the Currencycloud client.

  Starts a named `Finch` pool scoped to the Currencycloud API host. Each
  `Config` environment gets its own pool name so multiple clients (e.g. one
  per environment) can coexist in the same VM.

  ## Pool configuration

  The pool is configured from `CurrencycloudClient.Config`:

  - `:pool_size` → number of persistent HTTP/1.1 connections per pool.
  - `:timeout` / `:connect_timeout` → passed through to Finch requests.

  Finch uses HTTP/2 multiplexing automatically for HTTPS hosts that support
  it, giving you many concurrent requests over a single connection.

  ## Usage in a supervision tree

      children = [
        {CurrencycloudClient.FinchPool, config: my_config}
      ]

  Or let `CurrencycloudClient.Application` start it automatically.
  """

  use Supervisor

  alias CurrencycloudClient.Config

  @doc """
  Returns the Finch pool name for a given config.

  The name encodes the environment so that `:demo` and `:production`
  pools never collide inside the same BEAM node.
  """
  @spec pool_name(Config.t()) :: atom()
  def pool_name(%Config{finch_name: name}) when not is_nil(name), do: name
  def pool_name(%Config{environment: env}), do: :"CurrencycloudClient.Finch.#{env}"

  @doc """
  Starts the supervised Finch pool.

  ## Options
  - `:config` (required) – A `%CurrencycloudClient.Config{}`.
  - `:name` – Optional registered name for the supervisor itself.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    {sup_opts, init_opts} = Keyword.split(opts, [:name])
    Supervisor.start_link(__MODULE__, init_opts, sup_opts)
  end

  @impl Supervisor
  def init(opts) do
    config = Keyword.fetch!(opts, :config)
    name = pool_name(config)

    uri = URI.parse(config.base_url)
    host = uri.host

    finch_opts = [
      name: name,
      pools: %{
        "#{uri.scheme}://#{host}" => [
          size: config.pool_size,
          count: 1,
          # Use HTTP/2 when the server supports it (Currencycloud supports it)
          protocol: :http2,
          # TLS options — castore provides the trusted CA bundle
          conn_opts: [
            transport_opts: [
              verify: :verify_peer,
              cacerts: :public_key.cacerts_get(),
              server_name_indication: String.to_charlist(host),
              depth: 3
            ]
          ]
        ]
      }
    ]

    children = [
      {Finch, finch_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Builds a `Finch.Request` and executes it against the named pool.

  Wraps `Finch.build/5` + `Finch.request/3` and normalises the result
  into `{:ok, %{status, headers, body}}` or `{:error, exception}`.
  """
  @spec request(atom(), atom(), String.t(), list(), binary(), keyword()) ::
          {:ok, %{status: integer(), headers: list(), body: binary()}}
          | {:error, Exception.t()}
  def request(pool_name, method, url, headers, body, opts \\ []) do
    receive_timeout = Keyword.get(opts, :receive_timeout, 30_000)

    request = Finch.build(method, url, headers, body)

    case Finch.request(request, pool_name, receive_timeout: receive_timeout) do
      {:ok, %Finch.Response{status: status, headers: resp_headers, body: resp_body}} ->
        {:ok, %{status: status, headers: resp_headers, body: resp_body}}

      {:error, _} = err ->
        err
    end
  end
end
