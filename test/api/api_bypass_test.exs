defmodule CurrencycloudClient.API.BalancesTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Balances
  alias CurrencycloudClient.Error

  import Plug.Conn,
    only: [
      get_req_header: 2,
      put_resp_content_type: 2,
      put_resp_header: 3,
      read_body: 1,
      send_resp: 3
    ]

  setup :setup_bypass

  describe "get/2" do
    test "returns balance for a valid currency", %{bypass: bypass, client: client} do
      fixture = balance_fixture("EUR")
      stub_get(bypass, "/v2/balances/EUR", fixture)

      assert {:ok, balance} = Balances.get(client, "EUR")
      assert balance["currency"] == "EUR"
      assert balance["amount"] == "10000.00"
    end

    test "upcases the currency code", %{bypass: bypass, client: client} do
      fixture = balance_fixture("GBP")
      stub_get(bypass, "/v2/balances/GBP", fixture)

      assert {:ok, balance} = Balances.get(client, "gbp")
      assert balance["currency"] == "GBP"
    end

    test "returns AuthenticationError on 401", %{bypass: bypass, client: client} do
      stub_error(bypass, "GET", "/v2/balances/EUR", 401)

      assert {:error, %Error.AuthenticationError{}} = Balances.get(client, "EUR")
    end

    test "returns NotFoundError on 404", %{bypass: bypass, client: client} do
      stub_error(bypass, "GET", "/v2/balances/XYZ", 404)

      assert {:error, %Error.NotFoundError{}} = Balances.get(client, "XYZ")
    end

    test "returns TooManyRequestsError on 429", %{bypass: bypass, client: client} do
      Bypass.stub(bypass, "GET", "/v2/balances/EUR", fn conn ->
        conn
        |> put_resp_header("retry-after", "30")
        |> put_resp_content_type("application/json")
        |> send_resp(429, Jason.encode!(%{}))
      end)

      # With max_retries: 0 to avoid actual retries in tests
      fast_config = %{client.config | max_retries: 0}
      fast_client = %{client | config: fast_config}

      assert {:error, %Error.TooManyRequestsError{retry_after: 30}} =
               Balances.get(fast_client, "EUR")
    end
  end

  describe "find/2" do
    test "returns paginated balances", %{bypass: bypass, client: client} do
      response = paginated("balances", [balance_fixture("EUR"), balance_fixture("GBP")])
      stub_get(bypass, "/v2/balances/find", response)

      assert {:ok, result} = Balances.find(client)
      assert length(result["balances"]) == 2
      assert result["pagination"]["total_entries"] == 2
    end

    test "passes filter params in query string", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "GET", "/v2/balances/find", fn conn ->
        assert conn.query_string =~ "scope=non_zero"
        send_json(conn, 200, paginated("balances", []))
      end)

      assert {:ok, _} = Balances.find(client, %{"scope" => "non_zero"})
    end
  end

  describe "top_up_margin/2" do
    test "posts to top_up_margin and returns result", %{bypass: bypass, client: client} do
      stub_post(bypass, "/v2/balances/top_up_margin", %{
        "amount" => "1000.00",
        "currency" => "EUR"
      })

      assert {:ok, result} =
               Balances.top_up_margin(client, %{"currency" => "EUR", "amount" => "1000.00"})

      assert result["currency"] == "EUR"
    end
  end

  defp send_json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end

defmodule CurrencycloudClient.API.AccountsTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Accounts

  setup :setup_bypass

  describe "create/2" do
    test "creates an account and returns it", %{bypass: bypass, client: client} do
      fixture = account_fixture()
      expect_once(bypass, "POST", "/v2/accounts/create", fixture)

      assert {:ok, account} =
               Accounts.create(client, %{
                 "account_name" => "Test Co",
                 "legal_entity_type" => "company",
                 "country" => "GB"
               })

      assert account["account_name"] == "Test Company Ltd"
    end
  end

  describe "get/2" do
    test "retrieves an account by id", %{bypass: bypass, client: client} do
      id = uuid()
      fixture = account_fixture(%{"id" => id})
      stub_get(bypass, "/v2/accounts/#{id}", fixture)

      assert {:ok, account} = Accounts.get(client, id)
      assert account["id"] == id
    end
  end

  describe "find/2" do
    test "returns paginated accounts", %{bypass: bypass, client: client} do
      response = paginated("accounts", [account_fixture(), account_fixture()])
      stub_post(bypass, "/v2/accounts/find", response)

      assert {:ok, result} = Accounts.find(client)
      assert length(result["accounts"]) == 2
    end
  end

  describe "current/1" do
    test "returns the house account", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/accounts/current", account_fixture())

      assert {:ok, account} = Accounts.current(client)
      assert account["status"] == "enabled"
    end
  end
end

defmodule CurrencycloudClient.API.ConversionsTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Conversions

  import Plug.Conn,
    only: [
      get_req_header: 2,
      put_resp_content_type: 2,
      put_resp_header: 3,
      read_body: 1,
      send_resp: 3
    ]

  setup :setup_bypass

  describe "create/2" do
    test "books a conversion and returns entity", %{bypass: bypass, client: client} do
      fixture = conversion_fixture()
      expect_once(bypass, "POST", "/v2/conversions/create", fixture)

      assert {:ok, conversion} =
               Conversions.create(client, %{
                 "buy_currency" => "EUR",
                 "sell_currency" => "GBP",
                 "fixed_side" => "buy",
                 "amount" => "10000.00",
                 "term_agreement" => "true"
               })

      assert conversion["buy_currency"] == "EUR"
      assert conversion["status"] == "awaiting_funds"
    end
  end

  describe "get/2" do
    test "retrieves a conversion by id", %{bypass: bypass, client: client} do
      id = uuid()
      stub_get(bypass, "/v2/conversions/#{id}", conversion_fixture(%{"id" => id}))

      assert {:ok, conv} = Conversions.get(client, id)
      assert conv["id"] == id
    end
  end

  describe "find/2" do
    test "returns paginated conversions with filters", %{bypass: bypass, client: client} do
      response = paginated("conversions", [conversion_fixture()])

      Bypass.expect_once(bypass, "POST", "/v2/conversions/find", fn conn ->
        {:ok, body, _} = read_body(conn)
        params = URI.decode_query(body)
        assert params["status"] == "awaiting_funds"

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, result} = Conversions.find(client, %{"status" => "awaiting_funds"})
      assert length(result["conversions"]) == 1
    end
  end

  describe "split_preview/3" do
    test "returns split preview", %{bypass: bypass, client: client} do
      id = uuid()

      response = %{
        "parent_conversion" => conversion_fixture(%{"client_buy_amount" => "8000.00"}),
        "child_conversion" => conversion_fixture(%{"client_buy_amount" => "2000.00"})
      }

      stub_get(bypass, "/v2/conversions/#{id}/split_preview", response)

      assert {:ok, result} = Conversions.split_preview(client, id, "2000.00")
      assert result["child_conversion"]["client_buy_amount"] == "2000.00"
    end
  end

  describe "split/3" do
    test "executes a split", %{bypass: bypass, client: client} do
      id = uuid()

      response = %{
        "parent_conversion" => conversion_fixture(%{"client_buy_amount" => "8000.00"}),
        "child_conversion" => conversion_fixture(%{"client_buy_amount" => "2000.00"})
      }

      stub_post(bypass, "/v2/conversions/#{id}/split", response)

      assert {:ok, result} = Conversions.split(client, id, "2000.00")
      assert result["parent_conversion"]["client_buy_amount"] == "8000.00"
    end
  end

  describe "cancel/2" do
    test "cancels a conversion", %{bypass: bypass, client: client} do
      id = uuid()

      stub_post(
        bypass,
        "/v2/conversions/#{id}/cancel",
        conversion_fixture(%{"status" => "cancelled"})
      )

      assert {:ok, conv} = Conversions.cancel(client, id)
      assert conv["status"] == "cancelled"
    end
  end

  describe "profit_and_loss/2" do
    test "returns profit and loss data", %{bypass: bypass, client: client} do
      response = %{
        "profit_and_losses" => [%{"amount" => "50.00", "currency" => "GBP"}],
        "pagination" => %{"total_entries" => 1}
      }

      stub_get(bypass, "/v2/conversions/profit_and_loss", response)

      assert {:ok, result} = Conversions.profit_and_loss(client)
      assert length(result["profit_and_losses"]) == 1
    end
  end
end

defmodule CurrencycloudClient.API.PaymentsTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Payments
  alias CurrencycloudClient.Error

  import Plug.Conn,
    only: [
      get_req_header: 2,
      put_resp_content_type: 2,
      put_resp_header: 3,
      read_body: 1,
      send_resp: 3
    ]

  setup :setup_bypass

  describe "create/2" do
    test "creates a payment", %{bypass: bypass, client: client} do
      fixture = payment_fixture()
      expect_once(bypass, "POST", "/v2/payments/create", fixture)

      assert {:ok, payment} =
               Payments.create(client, %{
                 "currency" => "EUR",
                 "beneficiary_id" => uuid(),
                 "amount" => "10000.00",
                 "reason" => "Invoice",
                 "reference" => "INV-001"
               })

      assert payment["status"] == "ready_to_send"
      assert payment["currency"] == "EUR"
    end

    test "sends request body as form-encoded", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "POST", "/v2/payments/create", fn conn ->
        {:ok, body, _} = read_body(conn)
        params = URI.decode_query(body)
        assert params["currency"] == "EUR"
        assert params["amount"] == "10000.00"
        assert params["x-auth-token"] == nil

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(payment_fixture()))
      end)

      Payments.create(client, %{
        "currency" => "EUR",
        "beneficiary_id" => uuid(),
        "amount" => "10000.00",
        "reason" => "Test",
        "reference" => "REF-001"
      })
    end

    test "includes X-Auth-Token header", %{bypass: bypass, client: client} do
      Bypass.expect_once(bypass, "POST", "/v2/payments/create", fn conn ->
        token = get_req_header(conn, "x-auth-token")
        assert token == ["test-auth-token-abc123"]

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(payment_fixture()))
      end)

      Payments.create(client, %{
        "currency" => "EUR",
        "beneficiary_id" => uuid(),
        "amount" => "1.00",
        "reason" => "Test",
        "reference" => "REF"
      })
    end
  end

  describe "validate/2" do
    test "validates without SCA", %{bypass: bypass, client: client} do
      stub_post(bypass, "/v2/payments/validate", %{
        "id" => uuid(),
        "sca" => %{"required" => false}
      })

      assert {:ok, result} = Payments.validate(client, %{"currency" => "EUR"})
      assert result["sca"]["required"] == false
    end

    test "validates with SCA requirement", %{bypass: bypass, client: client} do
      stub_post(bypass, "/v2/payments/validate", %{
        "id" => uuid(),
        "sca" => %{"required" => true, "id" => "sca-abc", "type" => "SMS"}
      })

      assert {:ok, result} = Payments.validate(client, %{"currency" => "EUR"})
      assert result["sca"]["required"] == true
      assert result["sca"]["type"] == "SMS"
    end
  end

  describe "authorise/2" do
    test "authorises multiple payments", %{bypass: bypass, client: client} do
      ids = [uuid(), uuid()]

      stub_post(bypass, "/v2/payments/authorise", %{
        "authorised_payments" =>
          Enum.map(ids, &%{"id" => &1, "authorisation_steps_required" => 0}),
        "not_authorised_payments" => []
      })

      assert {:ok, result} = Payments.authorise(client, ids)
      assert length(result["authorised_payments"]) == 2
    end
  end

  describe "find/2" do
    test "returns paginated payments", %{bypass: bypass, client: client} do
      response = paginated("payments", [payment_fixture(), payment_fixture()])
      stub_post(bypass, "/v2/payments/find", response)

      assert {:ok, result} = Payments.find(client)
      assert length(result["payments"]) == 2
    end
  end

  describe "delete/2" do
    test "deletes a pending payment", %{bypass: bypass, client: client} do
      id = uuid()
      stub_post(bypass, "/v2/payments/delete/#{id}", payment_fixture(%{"status" => "deleted"}))

      assert {:ok, payment} = Payments.delete(client, id)
      assert payment["status"] == "deleted"
    end
  end

  describe "get_delivery_date/2" do
    test "returns delivery date info", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/payments/payment_delivery_date", %{
        "payment_delivery_date" => "2024-01-05",
        "payment_cutoff_time" => "2024-01-03T14:30:00+00:00"
      })

      assert {:ok, result} =
               Payments.get_delivery_date(client, %{
                 "payment_date" => "2024-01-03",
                 "payment_type" => "regular",
                 "currency" => "EUR",
                 "bank_country" => "DE"
               })

      assert result["payment_delivery_date"] == "2024-01-05"
    end
  end

  describe "resend_notification/2" do
    test "resends notification for a payment", %{bypass: bypass, client: client} do
      id = uuid()
      stub_post(bypass, "/v2/payments/#{id}/resend_notification", %{"success" => true})

      assert {:ok, result} = Payments.resend_notification(client, id)
      assert result["success"] == true
    end
  end

  describe "error handling" do
    test "returns BadRequestError with field errors on 400", %{bypass: bypass, client: client} do
      stub_error(bypass, "POST", "/v2/payments/create", 400, %{
        "currency" => [
          %{
            "code" => "currency_is_in_invalid_format",
            "message" => "Invalid currency",
            "params" => %{}
          }
        ]
      })

      fast_client = %{client | config: %{client.config | max_retries: 0}}

      assert {:error, %Error.BadRequestError{errors: [err | _]}} =
               Payments.create(fast_client, %{})

      assert err["field"] == "currency"
      assert err["code"] == "currency_is_in_invalid_format"
    end
  end
end

defmodule CurrencycloudClient.API.BeneficiariesTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Beneficiaries

  setup :setup_bypass

  describe "create/2" do
    test "creates a beneficiary", %{bypass: bypass, client: client} do
      fixture = beneficiary_fixture()
      expect_once(bypass, "POST", "/v2/beneficiaries/create", fixture)

      assert {:ok, b} =
               Beneficiaries.create(client, %{
                 "bank_account_holder_name" => "ACME GmbH",
                 "bank_country" => "DE",
                 "currency" => "EUR",
                 "iban" => "DE89370400440532013000",
                 "payment_types" => ["regular"]
               })

      assert b["bank_account_holder_name"] == "ACME GmbH"
    end
  end

  describe "validate/2" do
    test "validates beneficiary without saving", %{bypass: bypass, client: client} do
      stub_post(bypass, "/v2/beneficiaries/validate", beneficiary_fixture())

      assert {:ok, b} =
               Beneficiaries.validate(client, %{
                 "bank_account_holder_name" => "ACME GmbH",
                 "bank_country" => "DE",
                 "currency" => "EUR"
               })

      assert b["bank_country"] == "DE"
    end
  end

  describe "get/2" do
    test "retrieves a beneficiary by id", %{bypass: bypass, client: client} do
      id = uuid()
      stub_get(bypass, "/v2/beneficiaries/#{id}", beneficiary_fixture(%{"id" => id}))

      assert {:ok, b} = Beneficiaries.get(client, id)
      assert b["id"] == id
    end
  end

  describe "update/3" do
    test "updates a beneficiary", %{bypass: bypass, client: client} do
      id = uuid()
      updated = beneficiary_fixture(%{"id" => id, "bank_account_holder_name" => "Updated GmbH"})
      stub_post(bypass, "/v2/beneficiaries/update/#{id}", updated)

      assert {:ok, b} =
               Beneficiaries.update(client, id, %{"bank_account_holder_name" => "Updated GmbH"})

      assert b["bank_account_holder_name"] == "Updated GmbH"
    end
  end

  describe "delete/2" do
    test "deletes a beneficiary", %{bypass: bypass, client: client} do
      id = uuid()
      stub_post(bypass, "/v2/beneficiaries/delete/#{id}", beneficiary_fixture(%{"id" => id}))

      assert {:ok, b} = Beneficiaries.delete(client, id)
      assert b["id"] == id
    end
  end

  describe "find/2" do
    test "finds beneficiaries with filters", %{bypass: bypass, client: client} do
      response = paginated("beneficiaries", [beneficiary_fixture()])
      stub_post(bypass, "/v2/beneficiaries/find", response)

      assert {:ok, result} = Beneficiaries.find(client, %{"currency" => "EUR"})
      assert length(result["beneficiaries"]) == 1
    end
  end

  describe "verify_account/2" do
    test "verifies a beneficiary account (CoP)", %{bypass: bypass, client: client} do
      stub_post(bypass, "/v2/beneficiaries/account_verification", %{
        "result" => "matched",
        "account_name" => "ACME GmbH",
        "type" => "business"
      })

      assert {:ok, result} =
               Beneficiaries.verify_account(client, %{
                 "bank_account_holder_name" => "ACME GmbH",
                 "account_number" => "12345678",
                 "routing_code_type_1" => "sort_code",
                 "routing_code_value_1" => "040004",
                 "bank_country" => "GB",
                 "currency" => "GBP",
                 "payment_types" => ["regular"]
               })

      assert result["result"] == "matched"
    end
  end
end

defmodule CurrencycloudClient.API.RatesTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Rates

  setup :setup_bypass

  describe "get_basic/2" do
    test "returns indicative rates", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/rates/find", %{
        "rates" => %{"GBPEUR" => ["1.1590", "1.1600"]},
        "unavailable" => []
      })

      assert {:ok, result} = Rates.get_basic(client, %{"currency_pair" => "GBPEUR"})
      assert map_size(result["rates"]) == 1
    end
  end

  describe "get_detailed/2" do
    test "returns a detailed rate quote", %{bypass: bypass, client: client} do
      fixture = rate_fixture()
      stub_get(bypass, "/v2/rates/detailed", fixture)

      assert {:ok, rate} =
               Rates.get_detailed(client, %{
                 "buy_currency" => "EUR",
                 "sell_currency" => "GBP",
                 "fixed_side" => "buy",
                 "amount" => "10000.00"
               })

      assert rate["client_rate"] == "1.1590"
      assert rate["currency_pair"] == "GBPEUR"
    end
  end
end

defmodule CurrencycloudClient.API.ReferenceTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Reference

  setup :setup_bypass

  describe "get_available_currencies/1" do
    test "returns list of currencies", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/reference/currencies", %{
        "currencies" => [
          %{
            "code" => "GBP",
            "decimal_places" => 2,
            "name" => "British Pound",
            "online_trading" => true
          },
          %{"code" => "EUR", "decimal_places" => 2, "name" => "Euro", "online_trading" => true}
        ]
      })

      assert {:ok, result} = Reference.get_available_currencies(client)
      assert length(result["currencies"]) == 2
    end
  end

  describe "get_beneficiary_required_details/2" do
    test "returns required fields for EUR/DE", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/reference/beneficiary_required_details", %{
        "details" => [
          %{
            "payment_type" => "regular",
            "required_fields" => [
              %{"name" => "iban", "required" => true},
              %{"name" => "bic_swift", "required" => true}
            ]
          }
        ]
      })

      assert {:ok, result} =
               Reference.get_beneficiary_required_details(client, %{
                 "currency" => "EUR",
                 "bank_account_country" => "DE"
               })

      assert length(result["details"]) == 1
    end
  end

  describe "get_bank_details/2" do
    test "looks up bank details by IBAN", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/reference/bank_details", %{
        "bank_name" => "Commerzbank",
        "bank_country" => "DE",
        "bic" => "COBADEFFXXX"
      })

      assert {:ok, result} =
               Reference.get_bank_details(client, %{
                 "identifier_type" => "iban",
                 "identifier_value" => "DE89370400440532013000"
               })

      assert result["bank_name"] == "Commerzbank"
    end
  end

  describe "get_settlement_accounts/2" do
    test "returns settlement accounts (SSIs)", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/reference/settlement_accounts", %{
        "settlement_accounts" => [
          %{"currency" => "EUR", "bank_name" => "Barclays", "account_number" => "12345678"}
        ]
      })

      assert {:ok, result} = Reference.get_settlement_accounts(client)
      assert length(result["settlement_accounts"]) == 1
    end
  end

  describe "get_conversion_dates/2" do
    test "returns non-trading dates for a currency pair", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/reference/conversion_dates", %{
        "invalid_conversion_dates" => ["2024-12-25", "2025-01-01"],
        "first_conversion_date" => "2024-01-02"
      })

      assert {:ok, result} =
               Reference.get_conversion_dates(client, %{"conversion_pair" => "GBPEUR"})

      assert length(result["invalid_conversion_dates"]) == 2
    end
  end
end

defmodule CurrencycloudClient.API.TransfersTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Transfers

  setup :setup_bypass

  describe "create/2" do
    test "creates a transfer between accounts", %{bypass: bypass, client: client} do
      fixture = transfer_fixture()
      expect_once(bypass, "POST", "/v2/transfers/create", fixture)

      assert {:ok, transfer} =
               Transfers.create(client, %{
                 "source_account_id" => uuid(),
                 "destination_account_id" => uuid(),
                 "currency" => "EUR",
                 "amount" => "5000.00"
               })

      assert transfer["status"] == "completed"
      assert transfer["amount"] == "5000.00"
    end
  end

  describe "cancel/2" do
    test "cancels a pending transfer", %{bypass: bypass, client: client} do
      id = uuid()

      stub_post(
        bypass,
        "/v2/transfers/#{id}/cancel",
        transfer_fixture(%{"status" => "cancelled"})
      )

      assert {:ok, t} = Transfers.cancel(client, id)
      assert t["status"] == "cancelled"
    end
  end

  describe "find/2" do
    test "finds transfers with pagination", %{bypass: bypass, client: client} do
      response = paginated("transfers", [transfer_fixture()])
      stub_post(bypass, "/v2/transfers/find", response)

      assert {:ok, result} = Transfers.find(client)
      assert length(result["transfers"]) == 1
    end
  end
end

defmodule CurrencycloudClient.API.TransactionsTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Transactions

  import Plug.Conn,
    only: [
      get_req_header: 2,
      put_resp_content_type: 2,
      put_resp_header: 3,
      read_body: 1,
      send_resp: 3
    ]

  setup :setup_bypass

  describe "get/2" do
    test "retrieves a single transaction", %{bypass: bypass, client: client} do
      id = uuid()
      stub_get(bypass, "/v2/transactions/#{id}", transaction_fixture(%{"id" => id}))

      assert {:ok, txn} = Transactions.get(client, id)
      assert txn["id"] == id
      assert txn["type"] == "credit"
    end
  end

  describe "find/2" do
    test "returns paginated transactions with filters", %{bypass: bypass, client: client} do
      response = paginated("transactions", [transaction_fixture(), transaction_fixture()])

      Bypass.expect_once(bypass, "GET", "/v2/transactions/find", fn conn ->
        assert conn.query_string =~ "currency=EUR"

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, result} = Transactions.find(client, %{"currency" => "EUR"})
      assert length(result["transactions"]) == 2
    end
  end
end

defmodule CurrencycloudClient.API.FundingTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Funding

  setup :setup_bypass

  describe "find_funding_accounts/2" do
    test "returns funding accounts (SSIs)", %{bypass: bypass, client: client} do
      stub_get(bypass, "/v2/funding_accounts/find", %{
        "funding_accounts" => [
          %{
            "id" => uuid(),
            "account_id" => uuid(),
            "account_number" => "12345678",
            "account_number_type" => "iban",
            "account_holder_name" => "Currencycloud",
            "bank_name" => "Barclays",
            "bank_country" => "GB",
            "currency" => "EUR",
            "payment_type" => "regular"
          }
        ],
        "pagination" => %{"total_entries" => 1}
      })

      assert {:ok, result} = Funding.find_funding_accounts(client, %{"currency" => "EUR"})
      assert length(result["funding_accounts"]) == 1
    end
  end

  describe "get_sender_details/2" do
    test "retrieves sender details for an inbound transaction", %{bypass: bypass, client: client} do
      id = uuid()

      stub_get(bypass, "/v2/funding_accounts/sender_details/#{id}", %{
        "id" => id,
        "amount" => "10000.00",
        "currency" => "EUR",
        "sender" => %{
          "account_number" => "DE89370400440532013000",
          "bank_name" => "Deutsche Bank",
          "holder_name" => "Test GmbH"
        }
      })

      assert {:ok, result} = Funding.get_sender_details(client, id)
      assert result["sender"]["holder_name"] == "Test GmbH"
    end
  end
end

defmodule CurrencycloudClient.API.ContactsTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Contacts

  setup :setup_bypass

  describe "create/2" do
    test "creates a contact", %{bypass: bypass, client: client} do
      contact = %{
        "id" => uuid(),
        "account_id" => uuid(),
        "first_name" => "Alice",
        "last_name" => "Müller",
        "email_address" => "alice@example.com",
        "status" => "enabled"
      }

      expect_once(bypass, "POST", "/v2/contacts/create", contact)

      assert {:ok, c} =
               Contacts.create(client, %{
                 "account_id" => uuid(),
                 "first_name" => "Alice",
                 "last_name" => "Müller",
                 "email_address" => "alice@example.com",
                 "phone_number" => "+49301234567"
               })

      assert c["first_name"] == "Alice"
    end
  end

  describe "generate_hmac_key/2" do
    test "generates an HMAC key for webhook verification", %{bypass: bypass, client: client} do
      id = uuid()

      stub_post(bypass, "/v2/contacts/#{id}/generate_hmac_key", %{
        "hmac_key" => "test-hmac-secret-abc123"
      })

      assert {:ok, result} = Contacts.generate_hmac_key(client, id)
      assert String.length(result["hmac_key"]) > 0
    end
  end
end

defmodule CurrencycloudClient.API.ReportingTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.BypassHelper
  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Reporting

  setup :setup_bypass

  describe "create_payment_report/2" do
    test "requests a payment report and returns pending status", %{bypass: bypass, client: client} do
      stub_post(bypass, "/v2/reports/payments/create", %{
        "id" => uuid(),
        "status" => "processing",
        "description" => "Q1 payments"
      })

      assert {:ok, report} =
               Reporting.create_payment_report(client, %{
                 "description" => "Q1 payments",
                 "created_at_from" => "2024-01-01",
                 "created_at_to" => "2024-03-31"
               })

      assert report["status"] == "processing"
    end
  end

  describe "get_payment_report/2" do
    test "retrieves a completed report", %{bypass: bypass, client: client} do
      id = uuid()

      stub_get(bypass, "/v2/reports/payments/#{id}", %{
        "id" => id,
        "status" => "completed",
        "report_url" => "https://example.com/reports/#{id}.csv"
      })

      assert {:ok, report} = Reporting.get_payment_report(client, id)
      assert report["status"] == "completed"
    end
  end
end
