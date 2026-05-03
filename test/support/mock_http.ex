defmodule CurrencycloudClient.Test.MockHTTP do
  @moduledoc """
  A process-dictionary-based mock HTTP module for unit tests.

  Implements `CurrencycloudClient.HTTP.Behaviour` so it can be injected
  via the `:http_mod` field on `CurrencycloudClient.Client`.

  ## Usage

      # Stage a response for a URL path fragment
      CurrencycloudClient.Test.MockHTTP.put_response("/v2/balances/EUR", {:ok, %{"currency" => "EUR"}})

      # Build a client that uses this mock
      client = CurrencycloudClient.Test.Factory.build_client()

      # Call any API function — HTTP goes through MockHTTP, not Finch
      {:ok, balance} = CurrencycloudClient.API.Balances.get(client, "EUR")
  """

  @behaviour CurrencycloudClient.HTTP.Behaviour

  # ---------------------------------------------------------------------------
  # Behaviour callbacks
  # ---------------------------------------------------------------------------

  @impl CurrencycloudClient.HTTP.Behaviour
  def get(url, _params, _token, _config) do
    lookup(url)
  end

  @impl CurrencycloudClient.HTTP.Behaviour
  def post_form_unauthenticated(_url, _params, _config) do
    {:ok, %{"auth_token" => "test-auth-token-abc123"}}
  end

  @impl CurrencycloudClient.HTTP.Behaviour
  def post_form_authenticated(url, _params, _token, _config) do
    lookup(url)
  end

  @impl CurrencycloudClient.HTTP.Behaviour
  def delete(url, _params, _token, _config) do
    lookup(url)
  end

  @impl CurrencycloudClient.HTTP.Behaviour
  def put(url, _params, _token, _config) do
    lookup(url)
  end

  # ---------------------------------------------------------------------------
  # Test helpers — stage responses per test process
  # ---------------------------------------------------------------------------

  @doc """
  Stages a response for any URL whose path contains `path_fragment`.

  Responses are stored in the calling process's dictionary, so they are
  automatically isolated between async tests with no cleanup needed.

      MockHTTP.put_response("/v2/balances/EUR", {:ok, %{"amount" => "100.00"}})
      MockHTTP.put_response("/v2/payments/create", {:error, %BadRequestError{...}})
  """
  @spec put_response(String.t(), {:ok, map()} | {:error, term()}) :: :ok
  def put_response(path_fragment, response) do
    existing = Process.get(:mock_http_responses, %{})
    Process.put(:mock_http_responses, Map.put(existing, path_fragment, response))
    :ok
  end

  @doc """
  Stages a sequence of responses for a path fragment.
  Responses are returned in order, one per call.

      MockHTTP.put_responses("/v2/conversions/conv-1/cancel", [
        {:error, %TooManyRequestsError{...}},
        {:ok, %{"status" => "cancelled"}}
      ])
  """
  @spec put_responses(String.t(), [term()]) :: :ok
  def put_responses(path_fragment, responses) when is_list(responses) do
    existing = Process.get(:mock_http_queue, %{})
    Process.put(:mock_http_queue, Map.put(existing, path_fragment, responses))
    :ok
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp lookup(url) do
    queue = Process.get(:mock_http_queue, %{})
    responses = Process.get(:mock_http_responses, %{})

    dequeue(url, queue) || find_response(url, responses) || {:ok, %{}}
  end

  defp dequeue(url, queue) do
    case find_key(url, queue) do
      nil -> nil
      key -> pop_from_queue(key, Map.get(queue, key), queue)
    end
  end

  defp pop_from_queue(_key, [], _queue), do: nil

  defp pop_from_queue(key, [head | rest], queue) do
    updated = if rest == [], do: Map.delete(queue, key), else: Map.put(queue, key, rest)
    Process.put(:mock_http_queue, updated)
    head
  end

  defp find_response(url, responses) do
    case find_key(url, responses) do
      nil -> nil
      key -> Map.get(responses, key)
    end
  end

  defp find_key(url, map) do
    Enum.find_value(map, fn {pattern, _} ->
      if String.contains?(url, pattern), do: pattern
    end)
  end
end
