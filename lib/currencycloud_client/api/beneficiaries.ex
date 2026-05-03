defmodule CurrencycloudClient.API.Beneficiaries do
  @moduledoc """
  Beneficiaries API — manage payment recipients.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `create/2` | POST | `/v2/beneficiaries/create` |
  | `get/2` | GET | `/v2/beneficiaries/{id}` |
  | `update/3` | POST | `/v2/beneficiaries/update/{id}` |
  | `find/2` | POST | `/v2/beneficiaries/find` |
  | `delete/2` | POST | `/v2/beneficiaries/delete/{id}` |
  | `validate/2` | POST | `/v2/beneficiaries/validate` |
  | `verify_account/2` | POST | `/v2/beneficiaries/account_verification` |

  ## ⚠️  Beneficiary cloning

  Once a payment completes, the `beneficiary_id` on the payment record changes
  to a **cloned, read-only copy** of the beneficiary. Always persist your
  original beneficiary UUID separately if you intend to reuse it.

  ## Example

      # Validate first (dry-run, nothing saved)
      {:ok, validated} = CurrencycloudClient.API.Beneficiaries.validate(client, %{
        "bank_account_holder_name" => "ACME GmbH",
        "bank_country" => "DE",
        "currency" => "EUR",
        "account_number" => "DE89370400440532013000",
        "payment_types" => ["regular"]
      })

      # Create (persists to account)
      {:ok, beneficiary} = CurrencycloudClient.API.Beneficiaries.create(client, %{
        "bank_account_holder_name" => "ACME GmbH",
        "bank_country" => "DE",
        "currency" => "EUR",
        "iban" => "DE89370400440532013000",
        "bic_swift" => "COBADEFFXXX",
        "beneficiary_entity_type" => "company",
        "beneficiary_company_name" => "ACME GmbH",
        "beneficiary_country" => "DE",
        "payment_types" => ["regular"]
      })
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc """
  Creates a new beneficiary.

  Use `validate/2` first to check required fields for the currency/country
  combination before persisting.

  ## Required params (minimum)
  - `bank_account_holder_name`
  - `bank_country`
  - `currency`
  - `payment_types` – List: `["regular"]`, `["priority"]`, or both.
  - Plus routing fields appropriate for the currency (IBAN/BIC, account number, routing code).
  """
  @spec create(Client.t(), map()) :: Types.result(Types.beneficiary())
  def create(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/beneficiaries/create", stringify(params))
    end)
  end

  @doc "Retrieves a beneficiary by UUID."
  @spec get(Client.t(), Types.uuid()) :: Types.result(Types.beneficiary())
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/beneficiaries/#{id}", %{})
    end)
  end

  @doc "Updates a beneficiary. Only fields provided are updated (PATCH semantics)."
  @spec update(Client.t(), Types.uuid(), map()) :: Types.result(Types.beneficiary())
  def update(%Client{} = client, id, params) when is_binary(id) and is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/beneficiaries/update/#{id}", stringify(params))
    end)
  end

  @doc """
  Finds beneficiaries matching filter criteria.

  Returns `{:ok, %{"beneficiaries" => [...], "pagination" => %{...}}}`.

  ## Filter params
  - `bank_account_holder_name`, `beneficiary_country`, `currency`,
    `account_number`, `routing_code`, `payment_types`, `bic_swift`,
    `iban`, `name`, `beneficiary_entity_type`, `beneficiary_company_name`,
    `beneficiary_first_name`, `beneficiary_last_name`, `bank_name`,
    `bank_account_type`, `scope`
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/beneficiaries/find", stringify(params))
    end)
  end

  @doc "Permanently deletes a beneficiary. This action cannot be undone."
  @spec delete(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def delete(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/beneficiaries/delete/#{id}", %{})
    end)
  end

  @doc """
  Validates beneficiary details without saving them to the account.

  Returns the fully resolved beneficiary object (including which routing fields
  are required) — useful for building dynamic forms using Reference API data.

  Same params as `create/2`.
  """
  @spec validate(Client.t(), map()) :: Types.result(Types.beneficiary())
  def validate(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/beneficiaries/validate", stringify(params))
    end)
  end

  @doc """
  Verifies a beneficiary account via Confirmation of Payee (CoP / VoP).

  Performs a name-matching check for GBP domestic (UK) and EUR SEPA payments.
  Restricted to Currencycloud accounts enrolled in the CoP scheme.

  ## Required params
  - `bank_account_holder_name`
  - `account_number` or `iban`
  - `routing_code_type_1` + `routing_code_value_1` (UK sort code, etc.)
  - `bank_country`
  - `currency`
  - `payment_types`

  ## Returns

  `{:ok, %{"result" => "matched" | "close_match" | "not_matched" | "unavailable", ...}}`
  """
  @spec verify_account(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def verify_account(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/beneficiaries/account_verification", stringify(params))
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
