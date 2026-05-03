defmodule CurrencycloudClient.API.Conversions do
  @moduledoc """
  Conversions API — the full lifecycle of a foreign exchange trade.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `create/2` | POST | `/v2/conversions/create` |
  | `get/2` | GET | `/v2/conversions/{id}` |
  | `find/2` | POST | `/v2/conversions/find` |
  | `quote_cancel/2` | GET | `/v2/conversions/{id}/cancellation_quote` |
  | `cancel/2` | POST | `/v2/conversions/{id}/cancel` |
  | `quote_date_change/3` | GET | `/v2/conversions/{id}/date_change_quote` |
  | `date_change/3` | POST | `/v2/conversions/{id}/date_change` |
  | `split_preview/3` | GET | `/v2/conversions/{id}/split_preview` |
  | `split/3` | POST | `/v2/conversions/{id}/split` |
  | `split_history/2` | GET | `/v2/conversions/{id}/split_history` |
  | `profit_and_loss/2` | GET | `/v2/conversions/profit_and_loss` |

  ## Typical flow

      # 1. Get a firm rate
      {:ok, rate} = CurrencycloudClient.API.Rates.get_detailed(client, %{
        "buy_currency" => "EUR", "sell_currency" => "GBP",
        "fixed_side" => "buy", "amount" => "10000.00"
      })

      # 2. Book the conversion
      {:ok, conversion} = CurrencycloudClient.API.Conversions.create(client, %{
        "buy_currency" => "EUR",
        "sell_currency" => "GBP",
        "fixed_side" => "buy",
        "amount" => "10000.00",
        "reason" => "Invoice payment",
        "term_agreement" => "true"
      })
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc """
  Books a new FX conversion.

  ## Required params
  - `buy_currency` – Currency to buy.
  - `sell_currency` – Currency to sell.
  - `fixed_side` – `"buy"` or `"sell"`.
  - `amount` – Amount on the fixed side.
  - `term_agreement` – Must be `"true"` (indicates you've previewed the rate).

  ## Optional params
  - `conversion_date`, `client_rate`, `currency_pair`, `reason`,
    `unique_request_id`, `on_behalf_of`
  """
  @spec create(Client.t(), map()) :: Types.result(Types.conversion())
  def create(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/conversions/create", stringify(params))
    end)
  end

  @doc "Retrieves a conversion by UUID."
  @spec get(Client.t(), Types.uuid()) :: Types.result(Types.conversion())
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/conversions/#{id}", %{})
    end)
  end

  @doc """
  Finds conversions matching the given filter criteria.

  Returns `{:ok, %{"conversions" => [...], "pagination" => %{...}}}`.

  ## Filter params
  - `short_reference`, `status`, `buy_currency`, `sell_currency`,
    `currency_pair`, `partner_status`, `conversion_date_from`,
    `conversion_date_to`, `created_at_from`, `created_at_to`,
    `updated_at_from`, `updated_at_to`, `partner_buy_amount_from`,
    `partner_buy_amount_to`, `partner_sell_amount_from`,
    `partner_sell_amount_to`, `buy_amount_from`, `buy_amount_to`,
    `sell_amount_from`, `sell_amount_to`, `scope`, `unique_request_id`
  - Pagination: `page`, `per_page`, `order`, `order_asc_desc`
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/conversions/find", stringify(params))
    end)
  end

  @doc """
  Returns a quote for cancelling the given conversion, including the projected
  cost (the difference between original rate and current market rate).
  """
  @spec quote_cancel(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def quote_cancel(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/conversions/#{id}/cancellation_quote", %{})
    end)
  end

  @doc "Cancels the given conversion. Irreversible."
  @spec cancel(Client.t(), Types.uuid(), map()) :: {:ok, map()} | {:error, Error.t()}
  def cancel(%Client{} = client, id, params \\ %{}) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/conversions/#{id}/cancel", stringify(params))
    end)
  end

  @doc """
  Returns a quote for changing the value date of a conversion.
  `new_settlement_date` must be an ISO 8601 datetime string.
  """
  @spec quote_date_change(Client.t(), Types.uuid(), String.t()) ::
          {:ok, map()} | {:error, Error.t()}
  def quote_date_change(%Client{} = client, id, new_settlement_date)
      when is_binary(id) and is_binary(new_settlement_date) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/conversions/#{id}/date_change_quote", %{
        "new_settlement_date" => new_settlement_date
      })
    end)
  end

  @doc "Executes a value-date change on the given conversion."
  @spec date_change(Client.t(), Types.uuid(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def date_change(%Client{} = client, id, new_settlement_date)
      when is_binary(id) and is_binary(new_settlement_date) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/conversions/#{id}/date_change", %{
        "new_settlement_date" => new_settlement_date
      })
    end)
  end

  @doc """
  Previews splitting a conversion into a parent + child.

  ## Required params
  - `amount` – Amount to split off into the child conversion.
  """
  @spec split_preview(Client.t(), Types.uuid(), Types.amount()) ::
          {:ok, map()} | {:error, Error.t()}
  def split_preview(%Client{} = client, id, amount)
      when is_binary(id) and is_binary(amount) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/conversions/#{id}/split_preview", %{"amount" => amount})
    end)
  end

  @doc "Executes a split on the given conversion."
  @spec split(Client.t(), Types.uuid(), Types.amount()) :: {:ok, map()} | {:error, Error.t()}
  def split(%Client{} = client, id, amount) when is_binary(id) and is_binary(amount) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/conversions/#{id}/split", %{"amount" => amount})
    end)
  end

  @doc "Returns the split history for a conversion (parent/child relationships)."
  @spec split_history(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def split_history(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/conversions/#{id}/split_history", %{})
    end)
  end

  @doc """
  Returns profit and loss data for conversions, filtered by contact, account,
  date range, etc.

  ## Optional params
  - `contact_id`, `account_id`, `conversion_ids` (comma-separated),
    `start_date`, `end_date`, `page`, `per_page`
  """
  @spec profit_and_loss(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def profit_and_loss(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/conversions/profit_and_loss", stringify(params))
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
