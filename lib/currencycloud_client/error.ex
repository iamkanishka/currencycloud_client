defmodule CurrencycloudClient.Error do
  @moduledoc """
  Structured, typed error hierarchy for the Currencycloud client.

  Every error is one of the concrete structs below. All structs share the same
  fields: `request`, `response`, `errors`, `raw_body`. `TooManyRequestsError`
  adds `retry_after`. `NetworkError` has `reason` and `message` instead.

  ## Pattern matching

      case CurrencycloudClient.API.Payments.create(client, params) do
        {:ok, payment} -> payment
        {:error, %CurrencycloudClient.Error.BadRequestError{errors: errs}} ->
          Enum.each(errs, &IO.puts(&1["message"]))
        {:error, %CurrencycloudClient.Error.TooManyRequestsError{retry_after: secs}} ->
          Process.sleep(secs * 1_000)
        {:error, err} ->
          IO.puts(CurrencycloudClient.Error.to_diagnostic(err))
      end
  """

  # Shared field type
  @type field_error :: %{String.t() => String.t() | map()}

  @type request_info :: %{
          verb: String.t(),
          url: String.t(),
          params: map()
        }

  @type response_info :: %{
          status_code: non_neg_integer() | nil,
          request_id: String.t() | nil,
          date: String.t() | nil
        }

  # ---------------------------------------------------------------------------
  # Concrete error structs
  # ---------------------------------------------------------------------------

  defmodule AuthenticationError do
    @moduledoc "Raised on 401 — bad credentials or locked account."
    defstruct request: %{}, response: %{}, errors: [], raw_body: nil
    @type t :: %__MODULE__{request: map(), response: map(), errors: list(), raw_body: term()}
  end

  defmodule ForbiddenError do
    @moduledoc "Raised on 403 — insufficient permissions."
    defstruct request: %{}, response: %{}, errors: [], raw_body: nil
    @type t :: %__MODULE__{request: map(), response: map(), errors: list(), raw_body: term()}
  end

  defmodule BadRequestError do
    @moduledoc "Raised on 400 — validation failures. `errors` contains per-field details."
    defstruct request: %{}, response: %{}, errors: [], raw_body: nil
    @type t :: %__MODULE__{request: map(), response: map(), errors: list(), raw_body: term()}
  end

  defmodule NotFoundError do
    @moduledoc "Raised on 404 — resource does not exist."
    defstruct request: %{}, response: %{}, errors: [], raw_body: nil
    @type t :: %__MODULE__{request: map(), response: map(), errors: list(), raw_body: term()}
  end

  defmodule TooManyRequestsError do
    @moduledoc "Raised on 429 — rate limited. Check `retry_after` seconds."
    defstruct request: %{}, response: %{}, errors: [], raw_body: nil, retry_after: 60

    @type t :: %__MODULE__{
            request: map(),
            response: map(),
            errors: list(),
            raw_body: term(),
            retry_after: non_neg_integer()
          }
  end

  defmodule InternalServerError do
    @moduledoc "Raised on 5xx responses."
    defstruct request: %{}, response: %{}, errors: [], raw_body: nil
    @type t :: %__MODULE__{request: map(), response: map(), errors: list(), raw_body: term()}
  end

  defmodule NetworkError do
    @moduledoc "Raised on transport failures (DNS, timeout, connection reset)."
    defstruct reason: nil, message: nil
    @type t :: %__MODULE__{reason: atom() | term(), message: String.t() | nil}
  end

  defmodule UnexpectedError do
    @moduledoc "Catch-all for unexpected status codes or parse failures."
    defstruct request: %{}, response: %{}, errors: [], raw_body: nil
    @type t :: %__MODULE__{request: map(), response: map(), errors: list(), raw_body: term()}
  end

  @type t ::
          AuthenticationError.t()
          | ForbiddenError.t()
          | BadRequestError.t()
          | NotFoundError.t()
          | TooManyRequestsError.t()
          | InternalServerError.t()
          | NetworkError.t()
          | UnexpectedError.t()

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @doc "Returns a short human-readable summary."
  @spec message(t()) :: String.t()
  def message(%NetworkError{message: msg, reason: reason}),
    do: msg || "Network error: #{inspect(reason)}"

  def message(err) do
    module_name = err.__struct__ |> Module.split() |> List.last()
    status = get_in(err, [Access.key(:response, %{}), :status_code])

    field_summary =
      err
      |> Map.get(:errors, [])
      |> Enum.map_join("; ", fn e -> "#{e["field"]}: #{e["message"]}" end)

    if field_summary == "",
      do: "#{module_name} (HTTP #{status})",
      else: "#{module_name}: #{field_summary}"
  end

  @doc "Returns a detailed diagnostic string for logging."
  @spec to_diagnostic(t()) :: String.t()
  def to_diagnostic(%NetworkError{reason: r, message: msg}) do
    "NetworkError\n---\nreason: #{inspect(r)}\nmessage: #{msg}"
  end

  def to_diagnostic(err) do
    errors_text =
      err
      |> Map.get(:errors, [])
      |> Enum.map_join("\n", fn e ->
        "  - field: #{e["field"]}\n    code: #{e["code"]}\n    message: #{e["message"]}"
      end)

    req = Map.get(err, :request, %{})
    resp = Map.get(err, :response, %{})
    mod = err.__struct__ |> Module.split() |> Enum.join(".")

    """
    #{mod}
    ---
    request:
      verb: #{req[:verb]}
      url: #{req[:url]}
    response:
      status_code: #{resp[:status_code]}
      request_id: #{resp[:request_id]}
    errors:
    #{errors_text}
    """
    |> String.trim()
  end

  # ---------------------------------------------------------------------------
  # Internal builder — called by HTTP layer
  # ---------------------------------------------------------------------------

  @doc false
  @spec from_response(map(), map()) :: t()
  def from_response(req_info, %{status: status, body: body, headers: headers}) do
    errors = extract_errors(body)
    resp = build_resp_info(status, headers)
    retry_after = parse_retry_after(headers)
    build_error(status, req_info, resp, errors, body, retry_after)
  end

  defp build_resp_info(status, headers) do
    %{
      status_code: status,
      request_id: header(headers, "x-request-id"),
      date: header(headers, "date")
    }
  end

  defp build_error(status, req_info, resp, errors, body, retry_after) do
    case status do
      401 ->
        %AuthenticationError{request: req_info, response: resp, errors: errors, raw_body: body}

      403 ->
        %ForbiddenError{request: req_info, response: resp, errors: errors, raw_body: body}

      400 ->
        %BadRequestError{request: req_info, response: resp, errors: errors, raw_body: body}

      404 ->
        %NotFoundError{request: req_info, response: resp, errors: errors, raw_body: body}

      429 ->
        %TooManyRequestsError{
          request: req_info,
          response: resp,
          errors: errors,
          raw_body: body,
          retry_after: retry_after
        }

      s when s in 500..599 ->
        %InternalServerError{request: req_info, response: resp, errors: errors, raw_body: body}

      _ ->
        %UnexpectedError{request: req_info, response: resp, errors: errors, raw_body: body}
    end
  end

  @doc false
  @spec from_exception(term()) :: NetworkError.t()
  def from_exception(ex) do
    {reason, msg} =
      cond do
        is_atom(ex) ->
          {ex, to_string(ex)}

        is_map(ex) and is_atom(:erlang.map_get(:__struct__, ex)) ->
          r = Map.get(ex, :reason, :unknown)

          m =
            try do
              Exception.message(ex)
            rescue
              _ -> inspect(ex)
            end

          {r, m}

        true ->
          {:unknown, inspect(ex)}
      end

    %NetworkError{reason: reason, message: msg}
  end

  defp extract_errors(%{"error_messages" => msgs}) when is_map(msgs) do
    Enum.flat_map(msgs, fn {field, field_errors} ->
      Enum.map(field_errors, &Map.put(&1, "field", field))
    end)
  end

  defp extract_errors(_), do: []

  defp header(headers, key) when is_list(headers) do
    case List.keyfind(headers, key, 0) do
      {_k, v} -> v
      nil -> nil
    end
  end

  defp header(headers, key) when is_map(headers), do: Map.get(headers, key)
  defp header(_, _), do: nil

  defp parse_retry_after(headers) do
    case header(headers, "retry-after") do
      nil -> 60
      v -> String.to_integer(v)
    end
  rescue
    _ -> 60
  end
end
