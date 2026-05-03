defmodule CurrencycloudClient.API.Balances do
  @moduledoc """
  Balances API — retrieve and search account balances.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `get/2` | GET | `/v2/balances/{currency}` |
  | `find/2` | GET | `/v2/balances/find` |
  | `top_up_margin/2` | POST | `/v2/balances/top_up_margin` |

  ## Example

      # Get a specific currency balance
      {:ok, balance} = CurrencycloudClient.API.Balances.get(client, "EUR")
      IO.puts(balance["amount"])  #=> "12345.67"

      # Find all non-zero balances
      {:ok, result} = CurrencycloudClient.API.Balances.find(client, %{per_page: 50})
      result["balances"] |> Enum.each(fn b ->
        IO.puts("\#{b["currency"]}: \#{b["amount"]}")
      end)

      # For a sub-account
      sub_client = CurrencycloudClient.Client.on_behalf_of(client, contact_id)
      {:ok, balance} = CurrencycloudClient.API.Balances.get(sub_client, "GBP")
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc """
  Returns the balance for a single currency on the authenticated account.

  ## Parameters
  - `currency` – ISO 4217 currency code (e.g. `"EUR"`, `"GBP"`, `"USD"`).
  """
  @spec get(Client.t(), Types.currency()) :: Types.result(Types.balance())
  def get(%Client{} = client, currency) when is_binary(currency) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/balances/#{String.upcase(currency)}", %{})
    end)
  end

  @doc """
  Returns all balances for the authenticated account, with optional filters.

  Returns `{:ok, %{"balances" => [...], "pagination" => %{...}}}`.

  ## Optional params
  - `amount_from`, `amount_to` – Filter by balance range.
  - `as_at_date` – ISO 8601 date; returns balances as of that date.
  - `scope` – `"all"` or `"non_zero"`.
  - `page`, `per_page`, `order`, `order_asc_desc` – Pagination controls.
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/balances/find", stringify(params))
    end)
  end

  @doc """
  Tops up the margin balance for the authenticated account.

  Required for accounts that need a margin deposit to cover conversion risk.

  ## Required params
  - `currency` – The currency to top up.
  - `amount` – The amount to add to the margin balance.
  """
  @spec top_up_margin(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def top_up_margin(%Client{} = client, %{"currency" => _, "amount" => _} = params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/balances/top_up_margin", params)
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
