defmodule CurrencycloudClient.HTTP do
  @moduledoc """
  HTTP transport layer built on [Finch](https://github.com/sneako/finch).

  Handles connection pooling, auth headers, form encoding, JSON parsing,
  typed error mapping, and telemetry spans.

  Implements `CurrencycloudClient.HTTP.Behaviour` — swap it out in tests
  via the `:http_mod` key on `CurrencycloudClient.Client`.
  """

  alias CurrencycloudClient.Config
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.FinchPool
  alias CurrencycloudClient.Telemetry

  @content_type_form "application/x-www-form-urlencoded"
  @content_type_json "application/json"

  # ---------------------------------------------------------------------------
  # Behaviour — implemented here and mockable in tests
  # ---------------------------------------------------------------------------

  defmodule Behaviour do
    @moduledoc "Callback contract for the HTTP transport."

    @callback get(String.t(), map(), String.t(), CurrencycloudClient.Config.t()) ::
                {:ok, map()} | {:error, CurrencycloudClient.Error.t()}

    @callback post_form_unauthenticated(String.t(), map(), CurrencycloudClient.Config.t()) ::
                {:ok, map()} | {:error, CurrencycloudClient.Error.t()}

    @callback post_form_authenticated(
                String.t(),
                map(),
                String.t(),
                CurrencycloudClient.Config.t()
              ) ::
                {:ok, map()} | {:error, CurrencycloudClient.Error.t()}

    @callback delete(String.t(), map(), String.t(), CurrencycloudClient.Config.t()) ::
                {:ok, map()} | {:error, CurrencycloudClient.Error.t()}

    @callback put(String.t(), map(), String.t(), CurrencycloudClient.Config.t()) ::
                {:ok, map()} | {:error, CurrencycloudClient.Error.t()}
  end

  @behaviour Behaviour

  # ---------------------------------------------------------------------------
  # Public API — one function per HTTP verb
  # ---------------------------------------------------------------------------

  @impl Behaviour
  def get(url, params, token, %Config{} = config) do
    req_info = %{verb: "GET", url: url, params: params}
    full_url = append_query_string(url, params)
    headers = auth_headers(token, config)

    Telemetry.span(:request, %{method: :get, path: uri_path(url)}, fn ->
      finch_request(:get, full_url, headers, nil, req_info, config)
    end)
  end

  @impl Behaviour
  def post_form_unauthenticated(url, params, %Config{} = config) do
    req_info = %{verb: "POST", url: url, params: %{}}
    headers = base_headers(config) ++ [{"content-type", @content_type_form}]
    body = encode_form(params)

    Telemetry.span(:request, %{method: :post, path: uri_path(url)}, fn ->
      finch_request(:post, url, headers, body, req_info, config)
    end)
  end

  @impl Behaviour
  def post_form_authenticated(url, params, token, %Config{} = config) do
    req_info = %{verb: "POST", url: url, params: params}
    headers = auth_headers(token, config) ++ [{"content-type", @content_type_form}]
    # Assign to variable first so pipe starts with a raw value
    cleaned = clean_params(params)
    body = encode_form(cleaned)

    Telemetry.span(:request, %{method: :post, path: uri_path(url)}, fn ->
      finch_request(:post, url, headers, body, req_info, config)
    end)
  end

  @impl Behaviour
  def delete(url, params, token, %Config{} = config) do
    req_info = %{verb: "DELETE", url: url, params: params}
    headers = auth_headers(token, config) ++ [{"content-type", @content_type_form}]
    cleaned = clean_params(params)
    body = encode_form(cleaned)

    Telemetry.span(:request, %{method: :delete, path: uri_path(url)}, fn ->
      finch_request(:delete, url, headers, body, req_info, config)
    end)
  end

  @impl Behaviour
  def put(url, params, token, %Config{} = config) do
    req_info = %{verb: "PUT", url: url, params: params}
    headers = auth_headers(token, config) ++ [{"content-type", @content_type_form}]
    cleaned = clean_params(params)
    body = encode_form(cleaned)

    Telemetry.span(:request, %{method: :put, path: uri_path(url)}, fn ->
      finch_request(:put, url, headers, body, req_info, config)
    end)
  end

  # ---------------------------------------------------------------------------
  # Core Finch dispatch
  # ---------------------------------------------------------------------------

  defp finch_request(method, url, headers, body, req_info, %Config{} = config) do
    pool = FinchPool.pool_name(config)
    # Assign build result to variable so pipe starts with raw value
    req = Finch.build(method, url, headers, body)

    req
    |> Finch.request(pool, receive_timeout: config.timeout)
    |> handle_response(req_info)
  end

  # 2xx — success
  defp handle_response(
         {:ok, %Finch.Response{status: status, body: resp_body}},
         _req_info
       )
       when status in 200..299 do
    {:ok, decode_body(resp_body)}
  end

  # Non-2xx HTTP error
  defp handle_response(
         {:ok, %Finch.Response{status: status, headers: resp_headers, body: resp_body}},
         req_info
       ) do
    resp = %{status: status, body: decode_body(resp_body), headers: resp_headers}
    {:error, Error.from_response(req_info, resp)}
  end

  # Transport / network error
  defp handle_response({:error, exception}, _req_info) do
    {:error, Error.from_exception(exception)}
  end

  # ---------------------------------------------------------------------------
  # Headers
  # ---------------------------------------------------------------------------

  defp base_headers(%Config{user_agent: ua}) do
    [{"user-agent", ua}, {"accept", @content_type_json}]
  end

  defp auth_headers(token, %Config{} = config) do
    base_headers(config) ++ [{"x-auth-token", token}]
  end

  # ---------------------------------------------------------------------------
  # Param / body helpers
  # ---------------------------------------------------------------------------

  defp clean_params(params) when is_map(params) do
    # Each step assigned to a variable — no pipe starting with a function call
    rejected = Enum.reject(params, fn {_k, v} -> is_nil(v) end)
    mapped = Enum.map(rejected, fn {k, v} -> {to_string(k), scalar_to_string(v)} end)
    Map.new(mapped)
  end

  defp clean_params(params) when is_list(params) do
    params |> Map.new() |> clean_params()
  end

  defp scalar_to_string(v) when is_boolean(v), do: to_string(v)
  defp scalar_to_string(v) when is_number(v), do: to_string(v)
  defp scalar_to_string(v) when is_binary(v), do: v
  defp scalar_to_string(v) when is_atom(v), do: to_string(v)
  defp scalar_to_string(v), do: inspect(v)

  defp encode_form(nil), do: nil

  defp encode_form(params) when is_map(params) do
    Enum.map_join(params, "&", fn {k, v} ->
      URI.encode_www_form(to_string(k)) <> "=" <> URI.encode_www_form(to_string(v))
    end)
  end

  defp append_query_string(url, params) when map_size(params) == 0, do: url

  defp append_query_string(url, params) do
    cleaned = clean_params(params)
    query = URI.encode_query(cleaned)
    sep = if String.contains?(url, "?"), do: "&", else: "?"
    url <> sep <> query
  end

  # Finch response body is always a binary. A single binary clause handles all cases:
  # empty string → empty map, valid JSON → decoded map, other → raw string in map.
  # There is NO catchall non-binary clause — it would be unreachable.
  defp decode_body(body) when is_binary(body) do
    case body do
      "" ->
        %{}

      _ ->
        case Jason.decode(body) do
          {:ok, parsed} -> parsed
          {:error, _} -> %{"raw" => body}
        end
    end
  end

  defp uri_path(url) do
    case URI.parse(url) do
      %URI{path: path} when is_binary(path) -> path
      _ -> url
    end
  end
end
