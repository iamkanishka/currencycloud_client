defmodule CurrencycloudClient.API.Transactions do
  @moduledoc """
  Transactions API — unified ledger view across all activity types.

  A transaction is the ledger entry produced by any balance-affecting event:
  a conversion, payment, transfer, or inbound funding. This API lets you
  query the full ledger for an account or sub-account.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `get/2` | GET | `/v2/transactions/{id}` |
  | `find/2` | GET | `/v2/transactions/find` |

  ## Example

      # Paginate all EUR transactions in the last 30 days
      thirty_days_ago = Date.utc_today() |> Date.add(-30) |> Date.to_iso8601()

      {:ok, result} = CurrencycloudClient.API.Transactions.find(client, %{
        "currency" => "EUR",
        "created_at_from" => thirty_days_ago,
        "per_page" => 50,
        "order" => "created_at",
        "order_asc_desc" => "desc"
      })

      result["transactions"] |> Enum.each(fn txn ->
        IO.puts("\#{txn["type"]} \#{txn["currency"]} \#{txn["amount"]} (\#{txn["status"]})")
      end)
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc "Retrieves a single transaction by UUID."
  @spec get(Client.t(), Types.uuid()) :: Types.result(Types.transaction())
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/transactions/#{id}", %{})
    end)
  end

  @doc """
  Finds transactions matching the given filter criteria.

  Returns `{:ok, %{"transactions" => [...], "pagination" => %{...}}}`.

  ## Filter params
  - `currency` – ISO 4217 code.
  - `amount_from`, `amount_to` – Amount range.
  - `amount_scope` – `"absolute"` or `"instructed"`.
  - `action` – `"conversion"`, `"payment"`, `"inbound_funds"`, `"transfer"`.
  - `related_entity_type` – `"conversion"`, `"payment"`, `"inbound_funds"`, `"transfer"`.
  - `related_entity_id` – UUID of the related entity.
  - `related_entity_short_reference` – Short reference of the related entity.
  - `status` – `"completed"`, `"pending"`, `"deleted"`.
  - `type` – `"credit"` or `"debit"`.
  - `reason` – Free-text reason filter.
  - `settles_at_from`, `settles_at_to` – Settlement date range.
  - `created_at_from`, `created_at_to` – Creation date range.
  - `updated_at_from`, `updated_at_to` – Last-updated date range.
  - `scope` – `"all"` or specific scope string.
  - `page`, `per_page`, `order`, `order_asc_desc` – Pagination.
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/transactions/find", stringify(params))
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
