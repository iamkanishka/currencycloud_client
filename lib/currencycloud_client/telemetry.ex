defmodule CurrencycloudClient.Telemetry do
  @moduledoc """
  Telemetry integration for the Currencycloud client.

  This module emits `:telemetry` events for every HTTP request, token
  refresh, retry, and circuit-breaker state change. Attach handlers in
  your application's supervision tree to route metrics into Prometheus,
  Datadog, Statsd, or any other backend.

  ## Events emitted

  ### `[:currencycloud_client, :request, :start]`
  Emitted when an HTTP request begins.
  - Measurements: `%{system_time: integer()}`
  - Metadata: `%{method: atom(), path: String.t(), on_behalf_of: String.t() | nil}`

  ### `[:currencycloud_client, :request, :stop]`
  Emitted when an HTTP request completes (success or error).
  - Measurements: `%{duration: integer()}` (native time units)
  - Metadata: `%{method: atom(), path: String.t(), status: integer(), ok: boolean()}`

  ### `[:currencycloud_client, :request, :exception]`
  Emitted when an HTTP request raises an exception.
  - Measurements: `%{duration: integer()}`
  - Metadata: `%{method: atom(), path: String.t(), kind: atom(), reason: term()}`

  ### `[:currencycloud_client, :token, :refreshed]`
  Emitted after a successful token refresh.
  - Measurements: `%{system_time: integer()}`
  - Metadata: `%{login_id: String.t(), environment: atom()}`

  ### `[:currencycloud_client, :retry, :attempt]`
  Emitted on each retry attempt.
  - Measurements: `%{attempt: integer(), delay_ms: integer()}`
  - Metadata: `%{method: atom(), path: String.t(), reason: term()}`

  ## Attaching handlers

      :telemetry.attach_many(
        "my-app-cc-metrics",
        [
          [:currencycloud_client, :request, :stop],
          [:currencycloud_client, :retry, :attempt]
        ],
        &MyApp.Metrics.handle_event/4,
        nil
      )

  ## Logger handler (built-in, attach in tests or dev)

      CurrencycloudClient.Telemetry.attach_logger()
  """

  require Logger

  @prefix [:currencycloud_client]

  # ---------------------------------------------------------------------------
  # Event emitters (called by HTTP layer)
  # ---------------------------------------------------------------------------

  @doc false
  def span(event_name, metadata, fun) do
    start_time = System.monotonic_time()
    start_meta = Map.merge(metadata, %{system_time: System.system_time()})

    :telemetry.execute(
      @prefix ++ [event_name, :start],
      %{system_time: System.system_time()},
      start_meta
    )

    try do
      result = fun.()
      duration = System.monotonic_time() - start_time
      stop_meta = enrich_stop_meta(metadata, result)
      :telemetry.execute(@prefix ++ [event_name, :stop], %{duration: duration}, stop_meta)
      result
    rescue
      e ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          @prefix ++ [event_name, :exception],
          %{duration: duration},
          Map.merge(metadata, %{kind: :error, reason: e})
        )

        reraise e, __STACKTRACE__
    end
  end

  @doc false
  def emit_token_refreshed(login_id, environment) do
    :telemetry.execute(
      @prefix ++ [:token, :refreshed],
      %{system_time: System.system_time()},
      %{login_id: login_id, environment: environment}
    )
  end

  @doc false
  def emit_retry(attempt, delay_ms, method, path, reason) do
    :telemetry.execute(
      @prefix ++ [:retry, :attempt],
      %{attempt: attempt, delay_ms: delay_ms},
      %{method: method, path: path, reason: reason}
    )
  end

  # ---------------------------------------------------------------------------
  # Built-in logger handler
  # ---------------------------------------------------------------------------

  @doc """
  Attaches a simple Logger-based telemetry handler.
  Useful for development and debugging. Attach once at application start.

      CurrencycloudClient.Telemetry.attach_logger(level: :debug)
  """
  @spec attach_logger(keyword()) :: :ok | {:error, :already_exists}
  def attach_logger(opts \\ []) do
    level = Keyword.get(opts, :level, :info)

    :telemetry.attach_many(
      "currencycloud_client_logger",
      [
        @prefix ++ [:request, :stop],
        @prefix ++ [:request, :exception],
        @prefix ++ [:token, :refreshed],
        @prefix ++ [:retry, :attempt]
      ],
      &__MODULE__.__handle_log__/4,
      %{level: level}
    )
  end

  @doc false
  def __handle_log__([:currencycloud_client, :request, :stop], measurements, meta, config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    status = meta[:status] || "?"
    ok = if meta[:ok], do: "OK", else: "ERROR"

    Logger.log(
      config.level,
      "[CurrencycloudClient] #{meta[:method] |> to_string() |> String.upcase()} #{meta[:path]} → #{status} #{ok} (#{duration_ms}ms)"
    )
  end

  def __handle_log__([:currencycloud_client, :request, :exception], _measurements, meta, config) do
    Logger.log(
      config.level,
      "[CurrencycloudClient] #{meta[:method]} #{meta[:path]} EXCEPTION: #{inspect(meta[:reason])}"
    )
  end

  def __handle_log__([:currencycloud_client, :token, :refreshed], _measurements, meta, config) do
    Logger.log(
      config.level,
      "[CurrencycloudClient] Token refreshed for #{meta[:login_id]} (#{meta[:environment]})"
    )
  end

  def __handle_log__([:currencycloud_client, :retry, :attempt], measurements, meta, config) do
    Logger.log(
      config.level,
      "[CurrencycloudClient] Retry ##{measurements.attempt} for #{meta[:method]} #{meta[:path]} in #{measurements.delay_ms}ms (reason: #{inspect(meta[:reason])})"
    )
  end

  def __handle_log__(_, _, _, _), do: :ok

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp enrich_stop_meta(meta, {:ok, _}), do: Map.merge(meta, %{ok: true})

  defp enrich_stop_meta(meta, {:error, err}) do
    status = get_in(err, [Access.key(:response, %{}), :status_code])
    Map.merge(meta, %{ok: false, status: status})
  end

  defp enrich_stop_meta(meta, _), do: meta
end
