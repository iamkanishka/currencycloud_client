defmodule CurrencycloudClient.WebhooksTest do
  use ExUnit.Case, async: true

  alias CurrencycloudClient.Webhooks

  @hmac_key "test-hmac-secret-key-abc123"

  defp make_payload,
    do: ~s({"header":{"message_type":"payment_completed"},"body":{"payment":{"id":"abc"}}})

  defp sign(payload) do
    timestamp = to_string(System.system_time(:second))
    sig = Webhooks.compute_signature(@hmac_key, timestamp, payload)
    {sig, timestamp}
  end

  describe "verify/4" do
    test "returns :ok for a valid signature and fresh timestamp" do
      payload = make_payload()
      {sig, ts} = sign(payload)
      assert :ok = Webhooks.verify(@hmac_key, sig, ts, payload)
    end

    test "returns {:error, :invalid_signature} for wrong signature" do
      payload = make_payload()
      {_sig, ts} = sign(payload)
      assert {:error, :invalid_signature} = Webhooks.verify(@hmac_key, "bad-sig", ts, payload)
    end

    test "returns {:error, :timestamp_too_old} for expired timestamp" do
      payload = make_payload()
      old_ts = (System.system_time(:second) - 600) |> to_string()
      sig = Webhooks.compute_signature(@hmac_key, old_ts, payload)
      assert {:error, :timestamp_too_old} = Webhooks.verify(@hmac_key, sig, old_ts, payload)
    end

    test "returns {:error, :missing_headers} when signature is nil" do
      assert {:error, :missing_headers} = Webhooks.verify(@hmac_key, nil, "123", "body")
    end

    test "returns {:error, :missing_headers} when timestamp is nil" do
      assert {:error, :missing_headers} = Webhooks.verify(@hmac_key, "sig", nil, "body")
    end

    test "detects tampered body" do
      payload = make_payload()
      {sig, ts} = sign(payload)
      tampered = payload <> "extra"
      assert {:error, :invalid_signature} = Webhooks.verify(@hmac_key, sig, ts, tampered)
    end
  end

  describe "event_type/1" do
    test "extracts message_type from payload" do
      payload = %{"header" => %{"message_type" => "payment_completed"}}
      assert "payment_completed" = Webhooks.event_type(payload)
    end

    test "returns nil for malformed payload" do
      assert nil == Webhooks.event_type(%{})
    end
  end

  describe "notification_type/1" do
    test "extracts notification_type from payload" do
      payload = %{"header" => %{"notification_type" => "payment"}}
      assert "payment" = Webhooks.notification_type(payload)
    end
  end

  describe "entity/1" do
    test "extracts the entity body" do
      payload = %{"body" => %{"payment" => %{"id" => "abc"}}}
      assert %{"id" => "abc"} = Webhooks.entity(payload)
    end

    test "returns nil for missing body" do
      assert nil == Webhooks.entity(%{})
    end
  end

  describe "compute_signature/3" do
    test "produces a hex-encoded SHA256 HMAC" do
      sig = Webhooks.compute_signature(@hmac_key, "1234567890", "payload")
      assert String.length(sig) == 64
      assert sig =~ ~r/^[0-9a-f]+$/
    end

    test "different payloads produce different signatures" do
      sig1 = Webhooks.compute_signature(@hmac_key, "1234567890", "payload1")
      sig2 = Webhooks.compute_signature(@hmac_key, "1234567890", "payload2")
      refute sig1 == sig2
    end
  end
end
