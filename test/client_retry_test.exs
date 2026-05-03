defmodule CurrencycloudClient.ClientTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.Client

  describe "on_behalf_of/2" do
    test "returns a scoped client with the contact id set" do
      client = build_client()
      contact_id = uuid()
      sub = Client.on_behalf_of(client, contact_id)
      assert sub.on_behalf_of == contact_id
    end

    test "does not mutate the original client" do
      client = build_client()
      _sub = Client.on_behalf_of(client, uuid())
      assert client.on_behalf_of == nil
    end

    test "scoped client retains all other fields" do
      client = build_client()
      sub = Client.on_behalf_of(client, uuid())
      assert sub.config == client.config
      assert sub.session == client.session
    end
  end

  describe "clear_on_behalf_of/1" do
    test "removes sub-account scoping" do
      client = build_client(on_behalf_of: uuid())
      cleared = Client.clear_on_behalf_of(client)
      assert cleared.on_behalf_of == nil
    end
  end

  describe "url/2" do
    test "builds full URL from path" do
      client = build_client()

      assert Client.url(client, "/v2/balances/EUR") ==
               "https://devapi.currencycloud.com/v2/balances/EUR"
    end
  end

  describe "merge_on_behalf_of/2" do
    test "adds on_behalf_of to params when set on client" do
      contact_id = uuid()
      client = build_client(on_behalf_of: contact_id)
      params = %{"currency" => "EUR"}
      merged = Client.merge_on_behalf_of(client, params)
      assert merged["on_behalf_of"] == contact_id
    end

    test "does not overwrite existing on_behalf_of in params" do
      existing = uuid()
      client = build_client(on_behalf_of: uuid())
      merged = Client.merge_on_behalf_of(client, %{"on_behalf_of" => existing})
      assert merged["on_behalf_of"] == existing
    end

    test "leaves params unchanged when client has no on_behalf_of" do
      client = build_client()
      params = %{"currency" => "EUR"}
      assert Client.merge_on_behalf_of(client, params) == params
    end
  end

  describe "get_token/1" do
    test "returns token from mock session" do
      client = build_client()
      assert {:ok, "test-auth-token-abc123"} = Client.get_token(client)
    end
  end
end

defmodule CurrencycloudClient.RetryStrategyTest do
  use ExUnit.Case, async: true

  alias CurrencycloudClient.Config
  alias CurrencycloudClient.Error.{BadRequestError, InternalServerError, TooManyRequestsError}
  alias CurrencycloudClient.RetryStrategy

  @config Config.new!(
            environment: :demo,
            login_id: "t@t.com",
            api_key: "key",
            max_retries: 3,
            retry_base_delay: 1,
            retry_max_delay: 10
          )

  defp server_error do
    %InternalServerError{
      request: %{verb: "GET", url: "", params: %{}},
      response: %{status_code: 500, request_id: nil, date: nil},
      errors: []
    }
  end

  defp rate_limit_error do
    %TooManyRequestsError{
      request: %{verb: "GET", url: "", params: %{}},
      response: %{status_code: 429, request_id: nil, date: nil},
      errors: [],
      retry_after: 1
    }
  end

  defp bad_request_error do
    %BadRequestError{
      request: %{verb: "POST", url: "", params: %{}},
      response: %{status_code: 400, request_id: nil, date: nil},
      errors: []
    }
  end

  describe "with_retry/2" do
    test "returns {:ok, result} immediately on success" do
      assert {:ok, "done"} = RetryStrategy.with_retry(@config, fn -> {:ok, "done"} end)
    end

    test "retries on InternalServerError and succeeds on 3rd attempt" do
      counter = :counters.new(1, [])

      result =
        RetryStrategy.with_retry(@config, fn ->
          :counters.add(counter, 1, 1)
          count = :counters.get(counter, 1)
          if count < 3, do: {:error, server_error()}, else: {:ok, "recovered"}
        end)

      assert {:ok, "recovered"} = result
      assert :counters.get(counter, 1) == 3
    end

    test "exhausts retries and returns last error" do
      counter = :counters.new(1, [])

      result =
        RetryStrategy.with_retry(@config, fn ->
          :counters.add(counter, 1, 1)
          {:error, rate_limit_error()}
        end)

      assert {:error, %TooManyRequestsError{}} = result
      # 1 initial + 3 retries = 4 total calls
      assert :counters.get(counter, 1) == 4
    end

    test "does NOT retry BadRequestError (non-retryable)" do
      counter = :counters.new(1, [])

      result =
        RetryStrategy.with_retry(@config, fn ->
          :counters.add(counter, 1, 1)
          {:error, bad_request_error()}
        end)

      assert {:error, %BadRequestError{}} = result
      assert :counters.get(counter, 1) == 1
    end
  end

  describe "compute_delay/2" do
    test "returns a non-negative integer" do
      delay = RetryStrategy.compute_delay(0, @config)
      assert is_integer(delay)
      assert delay >= 0
    end

    test "delay is bounded by max_delay" do
      # Run many times to account for jitter
      delays = Enum.map(0..99, fn _ -> RetryStrategy.compute_delay(10, @config) end)
      assert Enum.all?(delays, fn d -> d <= 10 end)
    end
  end
end
