defmodule CurrencycloudClient.API.Transfers do
  @moduledoc """
  Transfers API — move funds between accounts in the same currency (no FX).

  Transfers move balances between your house account and a sub-account,
  or between two sub-accounts. No conversion takes place — both sides
  must be in the same currency.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `create/2` | POST | `/v2/transfers/create` |
  | `get/2` | GET | `/v2/transfers/{id}` |
  | `find/2` | POST | `/v2/transfers/find` |
  | `cancel/2` | POST | `/v2/transfers/{id}/cancel` |

  ## Example

      # Move EUR from house account to a sub-account
      {:ok, transfer} = CurrencycloudClient.API.Transfers.create(client, %{
        "source_account_id" => house_account_id,
        "destination_account_id" => sub_account_id,
        "currency" => "EUR",
        "amount" => "5000.00",
        "reason" => "Fund sub-account for payments"
      })

      IO.puts(transfer["status"])  #=> "completed"
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc """
  Creates a transfer between two accounts.

  ## Required params
  - `source_account_id` – UUID of the account to debit.
  - `destination_account_id` – UUID of the account to credit.
  - `currency` – ISO 4217 code (must be the same for both accounts).
  - `amount` – Amount to transfer (string).

  ## Optional params
  - `reason` – Free-text reason for the transfer.
  - `unique_request_id` – Idempotency key.
  """
  @spec create(Client.t(), map()) :: Types.result(Types.transfer())
  def create(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/transfers/create", stringify(params))
    end)
  end

  @doc "Retrieves a transfer by UUID."
  @spec get(Client.t(), Types.uuid()) :: Types.result(Types.transfer())
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/transfers/#{id}", %{})
    end)
  end

  @doc """
  Finds transfers matching the given filter criteria.

  Returns `{:ok, %{"transfers" => [...], "pagination" => %{...}}}`.

  ## Filter params
  - `short_reference`, `source_account_id`, `destination_account_id`,
    `currency`, `amount_from`, `amount_to`, `status`, `created_at_from`,
    `created_at_to`, `updated_at_from`, `updated_at_to`, `unique_request_id`
  - Pagination: `page`, `per_page`, `order`, `order_asc_desc`
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/transfers/find", stringify(params))
    end)
  end

  @doc """
  Cancels a pending transfer.

  Only transfers in `pending` status can be cancelled. Returns the updated
  transfer with `status: "cancelled"`.
  """
  @spec cancel(Client.t(), Types.uuid()) :: Types.result(Types.transfer())
  def cancel(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/transfers/#{id}/cancel", %{})
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
