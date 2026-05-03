defmodule CurrencycloudClient.API.Reference do
  @moduledoc """
  Reference API — look up static and semi-static data required to build
  valid payment and beneficiary requests.

  Always call these endpoints *before* creating beneficiaries or payments —
  the required fields differ by currency, country, and payment type.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `get_beneficiary_required_details/2` | GET | `/v2/reference/beneficiary_required_details` |
  | `get_available_currencies/1` | GET | `/v2/reference/currencies` |
  | `get_conversion_dates/2` | GET | `/v2/reference/conversion_dates` |
  | `get_payment_dates/2` | GET | `/v2/reference/payment_dates` |
  | `get_settlement_accounts/2` | GET | `/v2/reference/settlement_accounts` |
  | `get_payer_required_details/2` | GET | `/v2/reference/payer_required_details` |
  | `get_payment_purpose_codes/2` | GET | `/v2/reference/payment_purpose_codes` |
  | `get_bank_details/2` | GET | `/v2/reference/bank_details` |
  | `get_payment_fee_rules/2` | GET | `/v2/reference/payment_fee_rules` |

  ## Example — dynamic beneficiary form

      # 1. Find out what fields are needed for EUR payments to DE companies
      {:ok, details} = CurrencycloudClient.API.Reference.get_beneficiary_required_details(client, %{
        "currency" => "EUR",
        "bank_account_country" => "DE",
        "beneficiary_entity_type" => "company"
      })

      # 2. Render the form fields from details["details"]
      details["details"] |> Enum.each(fn group ->
        IO.inspect(group["required_fields"])
      end)
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy

  @doc """
  Returns the required fields for creating a beneficiary for a given
  currency, country, and entity type combination.

  ## Optional params
  - `currency` – Target payment currency.
  - `bank_account_country` – Country of the beneficiary's bank.
  - `beneficiary_entity_type` – `"company"` or `"individual"`.
  """
  @spec get_beneficiary_required_details(Client.t(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_beneficiary_required_details(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/beneficiary_required_details", stringify(params))
    end)
  end

  @doc """
  Returns the list of currencies available on the Currencycloud platform,
  including whether each supports buying, selling, and which payment types.
  """
  @spec get_available_currencies(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def get_available_currencies(%Client{} = client) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/currencies", %{})
    end)
  end

  @doc """
  Returns a list of non-trading dates (bank holidays) for a currency pair.

  ## Required params
  - `conversion_pair` – 6-char currency pair e.g. `"GBPEUR"`.

  ## Optional params
  - `start_date` – ISO 8601 date. Defaults to today.
  """
  @spec get_conversion_dates(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_conversion_dates(%Client{} = client, %{"conversion_pair" => _} = params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/conversion_dates", stringify(params))
    end)
  end

  @doc """
  Returns the non-payment dates (bank holidays) for a given currency.

  ## Required params
  - `currency` – ISO 4217 currency code.

  ## Optional params
  - `start_date` – ISO 8601 date. Defaults to today.
  """
  @spec get_payment_dates(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_payment_dates(%Client{} = client, %{"currency" => _} = params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/payment_dates", stringify(params))
    end)
  end

  @doc """
  Returns the settlement accounts (SSIs — Standard Settlement Instructions)
  for the given currency. These are the bank details your clients send funds to.

  ## Optional params
  - `currency` – ISO 4217 code. Returns all currencies if omitted.
  - `account_id` – Scopes to a specific sub-account.
  """
  @spec get_settlement_accounts(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_settlement_accounts(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/settlement_accounts", stringify(params))
    end)
  end

  @doc """
  Returns the required payer details for a given currency and country.

  Payer details are the sender information required by regulators on
  certain payment corridors.

  ## Required params
  - `payer_country` – ISO 3166-1 alpha-2 country code.

  ## Optional params
  - `payer_entity_type` – `"company"` or `"individual"`.
  - `payment_type` – `"regular"` or `"priority"`.
  """
  @spec get_payer_required_details(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_payer_required_details(%Client{} = client, %{"payer_country" => _} = params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/payer_required_details", stringify(params))
    end)
  end

  @doc """
  Returns the list of valid payment purpose codes for a given currency.

  Required for payments to certain corridors (e.g. INR, CNY) where
  regulators mandate a purpose code on the payment instruction.

  ## Required params
  - `currency` – ISO 4217 currency code.

  ## Optional params
  - `bank_account_country` – Country of the beneficiary's bank.
  - `entity_type` – `"company"` or `"individual"`.
  """
  @spec get_payment_purpose_codes(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_payment_purpose_codes(%Client{} = client, %{"currency" => _} = params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/payment_purpose_codes", stringify(params))
    end)
  end

  @doc """
  Looks up bank details by routing code or IBAN/BIC/SWIFT.

  ## Required params (one of)
  - `identifier_type` + `identifier_value` — e.g. `"iban"` + `"DE89370400440532013000"`,
    or `"sort_code"` + `"040004"`, or `"bic_swift"` + `"COBADEFFXXX"`.
  """
  @spec get_bank_details(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_bank_details(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/bank_details", stringify(params))
    end)
  end

  @doc """
  Returns the payment fee rules configured for the account.

  ## Optional params
  - `account_id` – Scopes to a sub-account.
  - `payment_type` – `"regular"` or `"priority"`.
  - `charge_type` – `"shared"`, `"ours"`, or `"theirs"`.
  """
  @spec get_payment_fee_rules(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_payment_fee_rules(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/reference/payment_fee_rules", stringify(params))
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
