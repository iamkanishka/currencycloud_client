defmodule CurrencycloudClient.API.Funding do
  @moduledoc """
  Funding API — manage inbound funds and funding account details.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `find_funding_accounts/2` | GET | `/v2/funding_accounts/find` |
  | `get_funding_transaction/2` | GET | `/v2/funding_accounts/transactions/{id}` |
  | `get_sender_details/2` | GET | `/v2/funding_accounts/sender_details/{id}` |
  | `emulate_inbound_funds/2` | POST | `/v2/funding_accounts/emulate_funds` |
  | `approve_transaction/2` | POST | `/v2/funding_accounts/transactions/{id}/approve` |
  | `reject_transaction/2` | POST | `/v2/funding_accounts/transactions/{id}/reject` |

  ## Example

      # Get SSIs (Standard Settlement Instructions) for all currencies
      {:ok, result} = CurrencycloudClient.API.Funding.find_funding_accounts(client, %{
        "currency" => "EUR"
      })

      result["funding_accounts"] |> Enum.each(fn acct ->
        IO.puts("Send \#{acct["currency"]} to \#{acct["bank_name"]}: \#{acct["account_number"]}")
      end)

      # Demo only — emulate an inbound fund receipt
      {:ok, _} = CurrencycloudClient.API.Funding.emulate_inbound_funds(client, %{
        "currency" => "EUR",
        "amount" => "10000.00",
        "account_id" => account_id
      })
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy

  @doc """
  Returns the funding accounts (SSIs) for the authenticated account.

  ## Optional params
  - `currency` – ISO 4217 code. Returns all currencies if omitted.
  - `account_id` – Scopes to a sub-account.
  - `payment_type` – `"regular"` or `"priority"`.
  - `page`, `per_page`, `order`, `order_asc_desc`
  """
  @spec find_funding_accounts(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find_funding_accounts(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/funding_accounts/find", stringify(params))
    end)
  end

  @doc "Retrieves details of a specific approved inbound funding transaction by UUID."
  @spec get_funding_transaction(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_funding_transaction(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/funding_accounts/transactions/#{id}", %{})
    end)
  end

  @doc """
  Returns the sender details (name, bank, account) for an inbound transaction.
  Used for compliance enrichment of inbound funds.
  """
  @spec get_sender_details(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_sender_details(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/funding_accounts/sender_details/#{id}", %{})
    end)
  end

  @doc """
  **Demo environment only.** Emulates an inbound fund receipt to trigger
  a balance top-up without making a real bank transfer.

  ## Required params
  - `currency` – Currency of the simulated inbound.
  - `amount` – Amount to credit.

  ## Optional params
  - `account_id` – Target sub-account (defaults to house account).
  """
  @spec emulate_inbound_funds(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def emulate_inbound_funds(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/funding_accounts/emulate_funds", stringify(params))
    end)
  end

  @doc """
  Approves an inbound transaction (for compliance-controlled funding flows).
  The transaction must be in `pending_approval` status.
  """
  @spec approve_transaction(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def approve_transaction(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/funding_accounts/transactions/#{id}/approve", %{})
    end)
  end

  @doc """
  Rejects an inbound transaction (for compliance-controlled funding flows).
  The funds will be returned to the sender.
  """
  @spec reject_transaction(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def reject_transaction(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/funding_accounts/transactions/#{id}/reject", %{})
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
