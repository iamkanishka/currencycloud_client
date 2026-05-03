defmodule CurrencycloudClient.Types do
  @moduledoc """
  Shared domain types used across all Currencycloud API modules.

  All monetary amounts are returned as strings by the API (e.g. `"1234.56"`)
  to preserve precision. We keep them as strings to avoid floating-point issues.
  Use `Decimal` if you need arithmetic.

  UUIDs are plain strings. ISO 4217 currency codes are 3-letter uppercase strings.
  ISO 3166-1 alpha-2 country codes are 2-letter uppercase strings.
  """

  # ---------------------------------------------------------------------------
  # Primitives
  # ---------------------------------------------------------------------------

  @typedoc ~s(ISO 4217 currency code e.g. "GBP", "EUR", "USD")
  @type currency :: String.t()

  @typedoc ~s(ISO 3166-1 alpha-2 country code e.g. "GB", "DE", "US")
  @type country :: String.t()

  @typedoc ~s(UUID string e.g. "3e84ab2e-4a76-...")
  @type uuid :: String.t()

  @typedoc ~s(Monetary amount as a string e.g. "1234.56")
  @type amount :: String.t()

  @typedoc ~s(ISO 8601 datetime string e.g. "2024-01-15T10:30:00+00:00")
  @type datetime_str :: String.t()

  @typedoc ~s(ISO 8601 date string e.g. "2024-01-15")
  @type date_str :: String.t()

  @typedoc ~s(The side of a conversion that is fixed: "buy" or "sell")
  @type fixed_side :: String.t()

  @typedoc ~s(Payment type: "priority" or "regular")
  @type payment_type :: String.t()

  @typedoc "Contact UUID used for on_behalf_of sub-account scoping"
  @type contact_id :: uuid()

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @typedoc "Pagination metadata returned on collection endpoints"
  @type pagination :: %{
          total_entries: non_neg_integer(),
          total_pages: non_neg_integer(),
          current_page: non_neg_integer(),
          per_page: non_neg_integer(),
          previous_page: integer(),
          next_page: integer(),
          order: String.t(),
          order_asc_desc: String.t()
        }

  # ---------------------------------------------------------------------------
  # Domain entities
  # ---------------------------------------------------------------------------

  @typedoc "Account entity"
  @type account :: %{
          id: uuid(),
          legal_entity_type: String.t(),
          account_name: String.t(),
          brand: String.t() | nil,
          your_reference: String.t() | nil,
          status: String.t(),
          street: String.t() | nil,
          city: String.t() | nil,
          state_or_province: String.t() | nil,
          country: country() | nil,
          postal_code: String.t() | nil,
          spread_table: String.t(),
          created_at: datetime_str(),
          updated_at: datetime_str(),
          identification_type: String.t() | nil,
          identification_value: String.t() | nil,
          short_reference: String.t(),
          api_trading: boolean(),
          online_trading: boolean(),
          phone_trading: boolean(),
          process_third_party_funds: boolean(),
          settlement_type: String.t(),
          terms_and_conditions_accepted: boolean() | nil
        }

  @typedoc "Balance entity"
  @type balance :: %{
          id: uuid(),
          account_id: uuid(),
          currency: currency(),
          amount: amount(),
          created_at: datetime_str(),
          updated_at: datetime_str()
        }

  @typedoc "Beneficiary entity"
  @type beneficiary :: %{
          id: uuid(),
          bank_account_holder_name: String.t(),
          name: String.t(),
          email: String.t() | nil,
          payment_types: [payment_type()],
          beneficiary_address: [String.t()],
          beneficiary_country: country(),
          beneficiary_entity_type: String.t(),
          beneficiary_company_name: String.t() | nil,
          beneficiary_first_name: String.t() | nil,
          beneficiary_last_name: String.t() | nil,
          beneficiary_city: String.t() | nil,
          beneficiary_postcode: String.t() | nil,
          beneficiary_state_or_province: String.t() | nil,
          beneficiary_date_of_birth: date_str() | nil,
          beneficiary_identification_type: String.t() | nil,
          beneficiary_identification_value: String.t() | nil,
          bank_country: country(),
          bank_name: String.t() | nil,
          bank_account_type: String.t() | nil,
          currency: currency(),
          account_number: String.t() | nil,
          routing_code_type_1: String.t() | nil,
          routing_code_value_1: String.t() | nil,
          routing_code_type_2: String.t() | nil,
          routing_code_value_2: String.t() | nil,
          bic_swift: String.t() | nil,
          iban: String.t() | nil,
          created_at: datetime_str(),
          updated_at: datetime_str()
        }

  @typedoc "Conversion entity"
  @type conversion :: %{
          id: uuid(),
          account_id: uuid(),
          creator_contact_id: uuid(),
          short_reference: String.t(),
          settlement_date: datetime_str(),
          conversion_date: date_str(),
          status: String.t(),
          partner_status: String.t(),
          currency_pair: String.t(),
          buy_currency: currency(),
          sell_currency: currency(),
          fixed_side: fixed_side(),
          partner_buy_amount: amount(),
          partner_sell_amount: amount(),
          client_buy_amount: amount(),
          client_sell_amount: amount(),
          mid_market_rate: amount(),
          core_rate: amount(),
          partner_rate: amount(),
          client_rate: amount(),
          deposit_required: boolean(),
          deposit_amount: amount(),
          deposit_currency: currency(),
          deposit_status: String.t(),
          deposit_required_at: datetime_str() | nil,
          payment_ids: [uuid()],
          created_at: datetime_str(),
          updated_at: datetime_str()
        }

  @typedoc "Payment entity"
  @type payment :: %{
          id: uuid(),
          amount: amount(),
          beneficiary_id: uuid(),
          currency: currency(),
          reference: String.t(),
          reason: String.t() | nil,
          status: String.t(),
          payment_type: payment_type(),
          payment_date: date_str(),
          transferred_at: datetime_str() | nil,
          authorisation_steps_required: non_neg_integer(),
          creator_contact_id: uuid(),
          last_updater_contact_id: uuid(),
          short_reference: String.t(),
          conversion_id: uuid() | nil,
          failure_reason: String.t(),
          payment_group_id: uuid() | nil,
          unique_request_id: String.t() | nil,
          fee_amount: amount() | nil,
          fee_currency: currency() | nil,
          failure_returned_amount: amount(),
          created_at: datetime_str(),
          updated_at: datetime_str()
        }

  @typedoc "Transfer entity"
  @type transfer :: %{
          id: uuid(),
          short_reference: String.t(),
          source_account_id: uuid(),
          destination_account_id: uuid(),
          currency: currency(),
          amount: amount(),
          status: String.t(),
          reason: String.t() | nil,
          created_at: datetime_str(),
          updated_at: datetime_str()
        }

  @typedoc "Transaction entity"
  @type transaction :: %{
          id: uuid(),
          account_id: uuid(),
          currency: currency(),
          amount: amount(),
          balance_amount: amount(),
          type: String.t(),
          related_entity_type: String.t(),
          related_entity_id: uuid() | nil,
          related_entity_short_reference: String.t() | nil,
          status: String.t(),
          reason: String.t() | nil,
          settles_at: datetime_str() | nil,
          created_at: datetime_str(),
          updated_at: datetime_str(),
          action: String.t()
        }

  @typedoc "Rate quote (detailed)"
  @type rate :: %{
          settlement_cut_off_time: datetime_str(),
          currency_pair: String.t(),
          client_buy_currency: currency(),
          client_sell_currency: currency(),
          client_buy_amount: amount(),
          client_sell_amount: amount(),
          fixed_side: fixed_side(),
          client_rate: amount(),
          partner_rate: amount() | nil,
          core_rate: amount(),
          deposit_required: boolean(),
          deposit_amount: amount(),
          deposit_currency: currency(),
          mid_market_rate: amount()
        }

  @typedoc "Pagination options accepted by list/find endpoints"
  @type pagination_opts :: %{
          optional(:page) => pos_integer(),
          optional(:per_page) => pos_integer(),
          optional(:order) => String.t(),
          optional(:order_asc_desc) => String.t()
        }

  @typedoc "Standard result for singular resource calls"
  @type result(entity) :: {:ok, entity} | {:error, CurrencycloudClient.Error.t()}

  @typedoc "Standard result for collection calls"
  @type collection_result(entity) ::
          {:ok, %{entries: [entity], pagination: pagination()}}
          | {:error, CurrencycloudClient.Error.t()}
end
