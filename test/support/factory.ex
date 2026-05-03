defmodule CurrencycloudClient.Test.Factory do
  @moduledoc "Test data factories for the CurrencycloudClient test suite."

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Config

  @doc "Builds a test Config struct with optional overrides."
  def build_config(overrides \\ []) do
    Config.new!(
      Keyword.merge(
        [environment: :demo, login_id: "test@example.com", api_key: "test-api-key"],
        overrides
      )
    )
  end

  @doc """
  Builds a test Client backed by MockSession (no real HTTP).
  For HTTP-level tests use `CurrencycloudClient.Test.BypassHelper.setup_bypass/1`.
  """
  def build_client(overrides \\ []) do
    config = build_config(Keyword.get(overrides, :config_overrides, []))
    obo = Keyword.get(overrides, :on_behalf_of, nil)

    %Client{
      config: config,
      session: CurrencycloudClient.Test.MockSession,
      http_mod: Keyword.get(overrides, :http_mod, CurrencycloudClient.HTTP),
      on_behalf_of: obo
    }
  end

  # ---------------------------------------------------------------------------
  # Domain fixtures
  # ---------------------------------------------------------------------------

  def account_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => uuid(),
        "legal_entity_type" => "company",
        "account_name" => "Test Company Ltd",
        "status" => "enabled",
        "street" => "1 Test Street",
        "city" => "London",
        "country" => "GB",
        "postal_code" => "EC1A 1BB",
        "spread_table" => "fxo_master_spread_0",
        "created_at" => "2024-01-01T00:00:00+00:00",
        "updated_at" => "2024-01-01T00:00:00+00:00",
        "short_reference" => "200101-XXXXX",
        "api_trading" => true,
        "online_trading" => true,
        "phone_trading" => false,
        "process_third_party_funds" => false,
        "settlement_type" => "net",
        "terms_and_conditions_accepted" => true
      },
      overrides
    )
  end

  def balance_fixture(currency \\ "EUR", overrides \\ %{}) do
    Map.merge(
      %{
        "id" => uuid(),
        "account_id" => uuid(),
        "currency" => currency,
        "amount" => "10000.00",
        "created_at" => "2024-01-01T00:00:00+00:00",
        "updated_at" => "2024-01-01T00:00:00+00:00"
      },
      overrides
    )
  end

  def conversion_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => uuid(),
        "account_id" => uuid(),
        "creator_contact_id" => uuid(),
        "short_reference" => "20240101-XXXXX",
        "settlement_date" => "2024-01-03T14:00:00+00:00",
        "conversion_date" => "2024-01-03",
        "status" => "awaiting_funds",
        "currency_pair" => "GBPEUR",
        "buy_currency" => "EUR",
        "sell_currency" => "GBP",
        "fixed_side" => "buy",
        "client_buy_amount" => "10000.00",
        "client_sell_amount" => "8621.55",
        "client_rate" => "1.1590",
        "mid_market_rate" => "1.1600",
        "deposit_required" => false,
        "deposit_amount" => "0.00",
        "deposit_currency" => "GBP",
        "deposit_status" => "not_required",
        "payment_ids" => [],
        "created_at" => "2024-01-01T00:00:00+00:00",
        "updated_at" => "2024-01-01T00:00:00+00:00"
      },
      overrides
    )
  end

  def payment_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => uuid(),
        "amount" => "10000.00",
        "beneficiary_id" => uuid(),
        "currency" => "EUR",
        "reference" => "INV-001",
        "reason" => "Invoice payment",
        "status" => "ready_to_send",
        "payment_type" => "regular",
        "payment_date" => "2024-01-03",
        "authorisation_steps_required" => 0,
        "creator_contact_id" => uuid(),
        "last_updater_contact_id" => uuid(),
        "short_reference" => "20240101-YYYYY",
        "failure_reason" => "",
        "failure_returned_amount" => "0.00",
        "created_at" => "2024-01-01T00:00:00+00:00",
        "updated_at" => "2024-01-01T00:00:00+00:00"
      },
      overrides
    )
  end

  def beneficiary_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => uuid(),
        "bank_account_holder_name" => "ACME GmbH",
        "name" => "ACME GmbH",
        "payment_types" => ["regular"],
        "beneficiary_address" => ["Unter den Linden 1"],
        "beneficiary_country" => "DE",
        "beneficiary_entity_type" => "company",
        "beneficiary_company_name" => "ACME GmbH",
        "bank_country" => "DE",
        "bank_name" => "Commerzbank",
        "currency" => "EUR",
        "iban" => "DE89370400440532013000",
        "bic_swift" => "COBADEFFXXX",
        "created_at" => "2024-01-01T00:00:00+00:00",
        "updated_at" => "2024-01-01T00:00:00+00:00"
      },
      overrides
    )
  end

  def transfer_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => uuid(),
        "short_reference" => "20240101-TTTTT",
        "source_account_id" => uuid(),
        "destination_account_id" => uuid(),
        "currency" => "EUR",
        "amount" => "5000.00",
        "status" => "completed",
        "created_at" => "2024-01-01T00:00:00+00:00",
        "updated_at" => "2024-01-01T00:00:00+00:00"
      },
      overrides
    )
  end

  def transaction_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => uuid(),
        "account_id" => uuid(),
        "currency" => "EUR",
        "amount" => "10000.00",
        "balance_amount" => "25000.00",
        "type" => "credit",
        "related_entity_type" => "conversion",
        "related_entity_id" => uuid(),
        "status" => "completed",
        "action" => "conversion",
        "created_at" => "2024-01-01T00:00:00+00:00",
        "updated_at" => "2024-01-01T00:00:00+00:00"
      },
      overrides
    )
  end

  def rate_fixture(overrides \\ %{}) do
    Map.merge(
      %{
        "settlement_cut_off_time" => "2024-01-03T14:30:00+00:00",
        "currency_pair" => "GBPEUR",
        "client_buy_currency" => "EUR",
        "client_sell_currency" => "GBP",
        "client_buy_amount" => "10000.00",
        "client_sell_amount" => "8621.55",
        "fixed_side" => "buy",
        "client_rate" => "1.1590",
        "mid_market_rate" => "1.1600",
        "deposit_required" => false,
        "deposit_amount" => "0.00",
        "deposit_currency" => "GBP"
      },
      overrides
    )
  end

  def paginated(entity_key, items, overrides \\ %{}) do
    Map.merge(
      %{
        entity_key => items,
        "pagination" => %{
          "total_entries" => length(items),
          "total_pages" => 1,
          "current_page" => 1,
          "per_page" => 25,
          "previous_page" => -1,
          "next_page" => -1,
          "order" => "created_at",
          "order_asc_desc" => "asc"
        }
      },
      overrides
    )
  end

  def uuid do
    raw = :crypto.strong_rand_bytes(16)
    hex = Base.encode16(raw, case: :lower)

    <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
      e::binary-size(12)>> = hex

    "#{a}-#{b}-#{c}-#{d}-#{e}"
  end
end

defmodule CurrencycloudClient.Test.MockSession do
  @moduledoc "A GenServer mock session for tests — always returns a fixed token."
  use GenServer

  def start_link(opts \\ []) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> GenServer.start_link(__MODULE__, :ok, name: name)
      :error -> GenServer.start_link(__MODULE__, :ok)
    end
  end

  def get_token(_server \\ __MODULE__), do: {:ok, "test-auth-token-abc123"}
  def refresh(_server \\ __MODULE__), do: :ok
  def logout(_server \\ __MODULE__), do: :ok

  @impl GenServer
  def init(:ok), do: {:ok, :mock}

  @impl GenServer
  def handle_call(:get_token, _from, state), do: {:reply, {:ok, "test-auth-token-abc123"}, state}
  def handle_call(:refresh, _from, state), do: {:reply, :ok, state}
  def handle_call(:logout, _from, state), do: {:reply, :ok, state}
end
