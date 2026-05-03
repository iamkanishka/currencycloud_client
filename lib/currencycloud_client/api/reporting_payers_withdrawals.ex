defmodule CurrencycloudClient.API.Reporting do
  @moduledoc """
  Reporting API — async generation of conversion and payment reports.

  Reports are generated asynchronously. You POST a request, then poll by ID
  until `status` is `"completed"` or `"failed"`.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `create_conversion_report/2` | POST | `/v2/reports/conversions/create` |
  | `get_conversion_report/2` | GET | `/v2/reports/conversions/{id}` |
  | `find_conversion_reports/2` | GET | `/v2/reports/conversions/find` |
  | `create_payment_report/2` | POST | `/v2/reports/payments/create` |
  | `get_payment_report/2` | GET | `/v2/reports/payments/{id}` |
  | `find_payment_reports/2` | GET | `/v2/reports/payments/find` |

  ## Example

      # Request a payment report
      {:ok, report} = CurrencycloudClient.API.Reporting.create_payment_report(client, %{
        "description" => "Q1 2024 payments",
        "created_at_from" => "2024-01-01",
        "created_at_to" => "2024-03-31"
      })

      # Poll until complete
      {:ok, done} = poll_until_complete(client, report["id"])

      defp poll_until_complete(client, report_id) do
        {:ok, r} = CurrencycloudClient.API.Reporting.get_payment_report(client, report_id)
        case r["status"] do
          "completed" -> {:ok, r}
          "failed" -> {:error, r}
          _ ->
            Process.sleep(2_000)
            poll_until_complete(client, report_id)
        end
      end
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy

  @doc "Requests generation of a conversion report."
  @spec create_conversion_report(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create_conversion_report(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/reports/conversions/create", stringify(params))
    end)
  end

  @doc "Retrieves a conversion report by UUID."
  @spec get_conversion_report(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_conversion_report(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reports/conversions/#{id}", %{})
    end)
  end

  @doc "Finds conversion reports matching filter criteria."
  @spec find_conversion_reports(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find_conversion_reports(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reports/conversions/find", stringify(params))
    end)
  end

  @doc "Requests generation of a payment report."
  @spec create_payment_report(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create_payment_report(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/reports/payments/create", stringify(params))
    end)
  end

  @doc "Retrieves a payment report by UUID."
  @spec get_payment_report(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_payment_report(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reports/payments/#{id}", %{})
    end)
  end

  @doc "Finds payment reports matching filter criteria."
  @spec find_payment_reports(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find_payment_reports(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reports/payments/find", stringify(params))
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end

defmodule CurrencycloudClient.API.Payers do
  @moduledoc """
  Payers API — retrieve the sender details attached to a payment.

  A Payer record captures the originator information (name, address, ID)
  that regulators require on outbound payments for certain corridors.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `get/2` | GET | `/v2/payers/{id}` |
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy

  @doc "Retrieves the payer record associated with a payment by UUID."
  @spec get(Client.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/payers/#{id}", %{})
    end)
  end
end

defmodule CurrencycloudClient.API.WithdrawalAccounts do
  @moduledoc """
  Withdrawal Accounts API — ACH pull of funds from a linked bank account.

  Allows you to pull funds from a linked US bank account into your
  Currencycloud balance via ACH debit.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `find/2` | GET | `/v2/withdrawal_accounts/find` |
  | `pull_funds/2` | POST | `/v2/withdrawal_accounts/pull_funds` |
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy

  @doc """
  Returns the withdrawal accounts (linked US bank accounts) for the
  authenticated account.

  ## Optional params
  - `account_id` – Scopes to a sub-account.
  - `page`, `per_page`, `order`, `order_asc_desc`
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/withdrawal_accounts/find", stringify(params))
    end)
  end

  @doc """
  Initiates a pull of funds from the linked bank account into the
  Currencycloud balance via ACH debit.

  ## Required params
  - `withdrawal_account_id` – UUID of the linked bank account.
  - `reference` – Your reference for the pull.
  - `amount` – Amount to pull (string).
  """
  @spec pull_funds(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def pull_funds(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/withdrawal_accounts/pull_funds", stringify(params))
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
