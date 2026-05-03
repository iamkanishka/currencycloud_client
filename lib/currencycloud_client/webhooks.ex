defmodule CurrencycloudClient.Webhooks do
  @moduledoc """
  Webhook signature verification and payload parsing.

  Currencycloud signs every webhook delivery with an HMAC-SHA256 signature.
  Always verify the signature before processing the payload to prevent
  spoofed webhook attacks.

  ## Setup

  1. Generate an HMAC key for your contact via the Contacts API:

         {:ok, result} = CurrencycloudClient.API.Contacts.generate_hmac_key(client, contact_id)
         hmac_key = result["hmac_key"]  # store this securely

  2. Verify incoming webhooks in your HTTP handler:

         def handle_webhook(conn) do
           signature = get_req_header(conn, "x-hmac-signature") |> List.first()
           timestamp  = get_req_header(conn, "x-hmac-timestamp")  |> List.first()
           raw_body   = conn.assigns.raw_body

           case CurrencycloudClient.Webhooks.verify(hmac_key, signature, timestamp, raw_body) do
             :ok ->
               payload = Jason.decode!(raw_body)
               process_event(payload)
               send_resp(conn, 200, "OK")

             {:error, :invalid_signature} ->
               send_resp(conn, 401, "Unauthorized")

             {:error, :timestamp_too_old} ->
               send_resp(conn, 400, "Replay attack detected")
           end
         end

  ## Payload structure

  Webhook payloads are JSON objects with `header` and `body` fields:

      %{
        "header" => %{
          "message_type" => "payment_completed",
          "notification_type" => "payment",
          "version" => 2
        },
        "body" => %{
          "payment" => %{ ... }
        }
      }

  ## Event types

  Common `message_type` values:
  - `payment_completed`
  - `payment_failed`
  - `payment_created`
  - `conversion_completed`
  - `conversion_created`
  - `inbound_funds_received`
  - `transfer_completed`
  """

  @max_timestamp_age_secs 300

  @type verify_error :: :invalid_signature | :timestamp_too_old | :missing_headers

  @doc """
  Verifies the HMAC-SHA256 signature of an incoming webhook delivery.

  ## Parameters
  - `hmac_key` – The HMAC key generated via the Contacts API.
  - `signature` – Value of the `X-HMAC-Signature` header.
  - `timestamp` – Value of the `X-HMAC-Timestamp` header (Unix epoch string).
  - `raw_body` – The raw (undecoded) request body bytes.

  ## Returns
  - `:ok` – Signature is valid and timestamp is within the replay window.
  - `{:error, :invalid_signature}` – Signature mismatch.
  - `{:error, :timestamp_too_old}` – Timestamp is more than 5 minutes old.
  - `{:error, :missing_headers}` – `signature` or `timestamp` is nil/empty.
  """
  @spec verify(String.t(), String.t() | nil, String.t() | nil, binary()) ::
          :ok | {:error, verify_error()}
  def verify(hmac_key, signature, timestamp, raw_body)
      when is_binary(signature) and is_binary(timestamp) do
    with :ok <- check_timestamp(timestamp) do
      check_signature(hmac_key, signature, timestamp, raw_body)
    end
  end

  def verify(_, nil, _, _), do: {:error, :missing_headers}
  def verify(_, _, nil, _), do: {:error, :missing_headers}

  @doc """
  Parses and returns the event type from a decoded webhook payload.

      {:ok, payload} = Jason.decode(raw_body)
      "payment_completed" = CurrencycloudClient.Webhooks.event_type(payload)
  """
  @spec event_type(map()) :: String.t() | nil
  def event_type(%{"header" => %{"message_type" => type}}), do: type
  def event_type(_), do: nil

  @doc """
  Parses and returns the notification type from a decoded webhook payload.

      "payment" = CurrencycloudClient.Webhooks.notification_type(payload)
  """
  @spec notification_type(map()) :: String.t() | nil
  def notification_type(%{"header" => %{"notification_type" => type}}), do: type
  def notification_type(_), do: nil

  @doc """
  Extracts the entity body from a decoded webhook payload.

      payment = CurrencycloudClient.Webhooks.entity(payload)
      payment["id"]  #=> "3e84ab2e-..."
  """
  @spec entity(map()) :: map() | nil
  def entity(%{"body" => body}) when is_map(body) do
    body |> Map.values() |> List.first()
  end

  def entity(_), do: nil

  @doc """
  Computes the expected HMAC-SHA256 signature for a given payload.
  Useful for generating test fixtures.

  The message signed is `timestamp <> raw_body`.
  """
  @spec compute_signature(String.t(), String.t(), binary()) :: String.t()
  def compute_signature(hmac_key, timestamp, raw_body) do
    message = timestamp <> raw_body

    mac = :crypto.mac(:hmac, :sha256, hmac_key, message)
    Base.encode16(mac, case: :lower)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp check_timestamp(timestamp) do
    case Integer.parse(timestamp) do
      {ts, ""} ->
        now = System.system_time(:second)
        age = abs(now - ts)

        if age <= @max_timestamp_age_secs do
          :ok
        else
          {:error, :timestamp_too_old}
        end

      _ ->
        {:error, :missing_headers}
    end
  end

  defp check_signature(hmac_key, provided_sig, timestamp, raw_body) do
    expected = compute_signature(hmac_key, timestamp, raw_body)

    if constant_compare(expected, String.downcase(provided_sig)),
      do: :ok,
      else: {:error, :invalid_signature}
  end

  # Constant-time binary comparison to prevent timing attacks
  defp constant_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp constant_compare(a, b) do
    :crypto.hash(:sha256, a) == :crypto.hash(:sha256, b) and a == b
  end
end
