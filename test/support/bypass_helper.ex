defmodule CurrencycloudClient.Test.BypassHelper do
  @moduledoc """
  Helpers for setting up Bypass HTTP mocks in tests.

  Each test that needs HTTP mocking calls `setup_bypass/1` in its setup block.
  The helper starts Bypass (which binds a real TCP port) and starts a Finch
  pool pointed at `localhost:<port>` so real HTTP/1.1 requests flow through
  the mock server.

  ## Usage

      defmodule MyTest do
        use ExUnit.Case
        import CurrencycloudClient.Test.BypassHelper

        setup :setup_bypass

        test "gets a balance", %{bypass: bypass, client: client} do
          stub_get(bypass, "/v2/balances/EUR", %{"currency" => "EUR", "amount" => "100.00"})
          assert {:ok, bal} = CurrencycloudClient.API.Balances.get(client, "EUR")
          assert bal["amount"] == "100.00"
        end
      end
  """

  import ExUnit.Callbacks, only: [start_supervised!: 1]

  import Plug.Conn,
    only: [
      get_req_header: 2,
      put_resp_content_type: 2,
      read_body: 1,
      send_resp: 3
    ]

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Config

  @doc """
  ExUnit setup helper. Starts Bypass, a Finch pool aimed at it, and a Client.

  Puts `%{bypass: bypass, client: client, config: config}` into the test context.
  """
  def setup_bypass(context) do
    bypass = Bypass.open()
    port = bypass.port

    config =
      Config.new!(
        environment: :demo,
        login_id: "test@example.com",
        api_key: "test-key",
        timeout: 5_000
      )

    config = %{config | base_url: "http://localhost:#{port}"}

    finch_name = :"TestFinch.#{System.unique_integer([:positive])}"

    start_supervised!({
      Finch,
      name: finch_name,
      pools: %{
        "http://localhost:#{port}" => [size: 2, protocol: :http1]
      }
    })

    config = %{config | finch_name: finch_name}
    client = Client.new(config, CurrencycloudClient.Test.MockSession)

    Map.merge(context, %{bypass: bypass, client: client, config: config})
  end

  @doc "Stubs a GET request returning the given JSON body."
  def stub_get(bypass, path, response_body, status \\ 200) do
    Bypass.stub(bypass, "GET", path, fn conn ->
      send_json(conn, status, response_body)
    end)
  end

  @doc "Stubs a POST request returning the given JSON body."
  def stub_post(bypass, path, response_body, status \\ 200) do
    Bypass.stub(bypass, "POST", path, fn conn ->
      send_json(conn, status, response_body)
    end)
  end

  @doc "Stubs a DELETE request returning the given JSON body."
  def stub_delete(bypass, path, response_body, status \\ 200) do
    Bypass.stub(bypass, "DELETE", path, fn conn ->
      send_json(conn, status, response_body)
    end)
  end

  @doc "Stubs a PUT request returning the given JSON body."
  def stub_put(bypass, path, response_body, status \\ 200) do
    Bypass.stub(bypass, "PUT", path, fn conn ->
      send_json(conn, status, response_body)
    end)
  end

  @doc "Stubs a request that returns an error body with the given HTTP status."
  def stub_error(bypass, method, path, status, error_messages \\ %{}) do
    Bypass.stub(bypass, method, path, fn conn ->
      body = %{"error_code" => "some_error", "error_messages" => error_messages}
      send_json(conn, status, body)
    end)
  end

  @doc "Expects exactly one call to the given method + path."
  def expect_once(bypass, method, path, response_body, status \\ 200) do
    Bypass.expect_once(bypass, method, path, fn conn ->
      send_json(conn, status, response_body)
    end)
  end

  @doc "Reads and form-decodes the request body from a Bypass conn."
  def read_form_body(conn) do
    {:ok, body, _conn} = read_body(conn)
    URI.decode_query(body)
  end

  @doc "Returns the value of `header` from a Bypass conn, or nil."
  def get_header(conn, header) do
    case get_req_header(conn, header) do
      [value | _] -> value
      [] -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp send_json(conn, status, body) when is_map(body) do
    encoded = Jason.encode!(body)
    conn = put_resp_content_type(conn, "application/json")
    send_resp(conn, status, encoded)
  end

  defp send_json(conn, status, body) when is_binary(body) do
    conn = put_resp_content_type(conn, "application/json")
    send_resp(conn, status, body)
  end
end
