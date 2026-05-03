defmodule CurrencycloudClient.Session do
  @moduledoc """
  GenServer that manages the Currencycloud authentication token lifecycle.

  ## Responsibilities

  - Fetches a fresh token on startup.
  - Caches the token in-process; all API calls retrieve it from here.
  - Proactively refreshes the token `config.token_refresh_buffer` seconds before
    the 30-minute Currencycloud expiry window closes (default: 2 minutes early).
  - Automatically re-authenticates on `401 AuthenticationError`.
  - Emits telemetry events on token refresh.
  - Supports per-instance naming so you can run multiple sessions (e.g. one per
    sub-account environment) side by side.

  ## Usage (supervised)

      # In your application supervision tree:
      {CurrencycloudClient.Session, config: config, name: MyApp.CCSession}

      # Anywhere in your code:
      {:ok, token} = CurrencycloudClient.Session.get_token(MyApp.CCSession)

  ## Usage (anonymous, for testing)

      {:ok, pid} = CurrencycloudClient.Session.start_link(config: config)
      {:ok, token} = CurrencycloudClient.Session.get_token(pid)
  """

  use GenServer, restart: :permanent

  require Logger

  alias CurrencycloudClient.Error
  alias CurrencycloudClient.Telemetry

  # Token expires after 30 min of inactivity; we treat it as ~28 min max TTL.
  @token_ttl_seconds 1_680

  defstruct [
    :config,
    :token,
    :expires_at,
    :refresh_timer,
    :http_mod
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts a Session GenServer.

  ## Options

  - `:config` (required) – A `%CurrencycloudClient.Config{}`.
  - `:name` – Optional registered name. Defaults to anonymous.
  - `:http_mod` – Override HTTP module (for testing). Defaults to `CurrencycloudClient.HTTP`.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {gen_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, gen_opts)
  end

  @doc "Returns the current auth token, refreshing if necessary."
  @spec get_token(GenServer.server()) :: {:ok, String.t()} | {:error, Error.t()}
  def get_token(server), do: GenServer.call(server, :get_token)

  @doc "Forces an immediate token refresh regardless of expiry."
  @spec refresh(GenServer.server()) :: :ok | {:error, Error.t()}
  def refresh(server), do: GenServer.call(server, :refresh)

  @doc "Explicitly logs out and clears the cached token."
  @spec logout(GenServer.server()) :: :ok
  def logout(server), do: GenServer.call(server, :logout)

  @doc "Returns the current state (for debugging/introspection)."
  @spec state(GenServer.server()) :: map()
  def state(server), do: GenServer.call(server, :state)

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    config = Keyword.fetch!(opts, :config)
    http_mod = Keyword.get(opts, :http_mod, CurrencycloudClient.HTTP)

    state = %__MODULE__{
      config: config,
      token: nil,
      expires_at: nil,
      refresh_timer: nil,
      http_mod: http_mod
    }

    # Authenticate immediately; if it fails, crash and let the supervisor retry
    case do_authenticate(state) do
      {:ok, new_state} ->
        {:ok, new_state}

      {:error, err} ->
        Logger.error(
          "[CurrencycloudClient.Session] Initial authentication failed: #{Error.to_diagnostic(err)}"
        )

        {:stop, {:authentication_failed, err}}
    end
  end

  @impl GenServer
  def handle_call(:get_token, _from, state) do
    if token_expired?(state) do
      case do_authenticate(state) do
        {:ok, new_state} -> {:reply, {:ok, new_state.token}, new_state}
        {:error, err} -> {:reply, {:error, err}, state}
      end
    else
      {:reply, {:ok, state.token}, state}
    end
  end

  def handle_call(:refresh, _from, state) do
    case do_authenticate(state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, err} -> {:reply, {:error, err}, state}
    end
  end

  def handle_call(:logout, _from, state) do
    _ = cancel_refresh_timer(state)
    _ = do_logout(state)
    {:reply, :ok, %{state | token: nil, expires_at: nil, refresh_timer: nil}}
  end

  def handle_call(:state, _from, state) do
    safe = %{
      token: if(state.token, do: "[REDACTED]", else: nil),
      expires_at: state.expires_at,
      environment: state.config.environment
    }

    {:reply, safe, state}
  end

  @impl GenServer
  def handle_info(:refresh_token, state) do
    Logger.debug("[CurrencycloudClient.Session] Proactive token refresh triggered")

    case do_authenticate(state) do
      {:ok, new_state} ->
        {:noreply, new_state}

      {:error, err} ->
        Logger.warning(
          "[CurrencycloudClient.Session] Proactive refresh failed: #{Error.message(err)}"
        )

        # Schedule a shorter retry
        timer = Process.send_after(self(), :refresh_token, 30_000)
        {:noreply, %{state | refresh_timer: timer}}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("[CurrencycloudClient.Session] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    _ = cancel_refresh_timer(state)
    _ = do_logout(state)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private – authentication
  # ---------------------------------------------------------------------------

  defp do_authenticate(%__MODULE__{config: config, http_mod: http_mod} = state) do
    url = config.base_url <> "/v2/authenticate/api"
    params = %{"login_id" => config.login_id, "api_key" => config.api_key}

    case http_mod.post_form_unauthenticated(url, params, config) do
      {:ok, %{"auth_token" => token}} ->
        {:ok, apply_new_token(state, token)}

      {:error, _} = err ->
        err
    end
  end

  defp apply_new_token(%__MODULE__{config: config} = state, token) do
    Telemetry.emit_token_refreshed(config.login_id, config.environment)

    expires_at = DateTime.add(DateTime.utc_now(), @token_ttl_seconds, :second)

    _ = cancel_refresh_timer(state)

    refresh_in_ms = max((@token_ttl_seconds - config.token_refresh_buffer) * 1_000, 5_000)
    timer = Process.send_after(self(), :refresh_token, refresh_in_ms)

    %{state | token: token, expires_at: expires_at, refresh_timer: timer}
  end

  defp do_logout(%__MODULE__{token: nil}), do: :ok

  defp do_logout(%__MODULE__{config: config, token: token, http_mod: http_mod})
       when not is_nil(token) do
    url = config.base_url <> "/v2/authenticate/close_session"
    http_mod.post_form_authenticated(url, %{}, token, config)
    :ok
  rescue
    _ -> :ok
  end

  defp token_expired?(%__MODULE__{token: nil}), do: true
  defp token_expired?(%__MODULE__{expires_at: nil}), do: true

  defp token_expired?(%__MODULE__{expires_at: expires_at, config: config})
       when not is_nil(expires_at) do
    buffer = config.token_refresh_buffer
    threshold = DateTime.add(DateTime.utc_now(), buffer, :second)
    DateTime.compare(expires_at, threshold) == :lt
  end

  defp cancel_refresh_timer(%__MODULE__{refresh_timer: nil}), do: :ok

  defp cancel_refresh_timer(%__MODULE__{refresh_timer: timer}) do
    Process.cancel_timer(timer)
    :ok
  end
end
