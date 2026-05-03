defmodule CurrencycloudClient.RetryStrategy do
  @moduledoc """
  Exponential backoff with full jitter for transient error recovery.

  Mirrors the JS SDK's `retry()` behaviour: retries on `TooManyRequestsError`,
  `InternalServerError`, and `NetworkError`; gives up immediately on
  `AuthenticationError`, `BadRequestError`, `NotFoundError`, `ForbiddenError`.

  ## Algorithm (full jitter)

      base = min(base_delay * 2^attempt, max_delay)
      sleep(rand(0, base))

  Full-jitter avoids thundering-herd when many processes retry simultaneously.

  ## Usage

      CurrencycloudClient.RetryStrategy.with_retry(config, fn ->
        CurrencycloudClient.API.Balances.get(client, "EUR")
      end)
  """

  alias CurrencycloudClient.Config
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.Telemetry

  @doc """
  Executes `fun` with automatic retry on transient errors.

  Returns `{:ok, result}` on success, or `{:error, error}` when all
  retries are exhausted or a non-retryable error occurs.
  """
  @spec with_retry(Config.t(), (-> {:ok, term()} | {:error, Error.t()})) ::
          {:ok, term()} | {:error, Error.t()}
  def with_retry(%Config{} = config, fun, attempt \\ 0) do
    case fun.() do
      {:ok, _} = ok ->
        ok

      {:error, err} ->
        if retryable?(err) and attempt < config.max_retries do
          delay = compute_delay(attempt, config)
          Telemetry.emit_retry(attempt + 1, delay, nil, nil, err.__struct__)
          Process.sleep(delay)
          with_retry(config, fun, attempt + 1)
        else
          {:error, err}
        end
    end
  end

  @doc "Computes the jittered delay in milliseconds for a given attempt index."
  @spec compute_delay(non_neg_integer(), Config.t()) :: non_neg_integer()
  def compute_delay(attempt, %Config{retry_base_delay: base, retry_max_delay: max_d}) do
    capped = min(base * :math.pow(2, attempt), max_d * 1.0)
    round(:rand.uniform() * capped)
  end

  defp retryable?(%Error.TooManyRequestsError{}), do: true
  defp retryable?(%Error.InternalServerError{}), do: true
  defp retryable?(%Error.NetworkError{}), do: true
  defp retryable?(_), do: false
end
