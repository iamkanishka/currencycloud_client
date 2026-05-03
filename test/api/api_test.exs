defmodule CurrencycloudClient.API.BalancesTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Balances
  alias CurrencycloudClient.Test.MockHTTP

  setup do
    {:ok, client: build_client()}
  end

  describe "get/2" do
    test "returns a balance for a valid currency", %{client: client} do
      fixture = balance_fixture("EUR")
      MockHTTP.put_response("/v2/balances/EUR", {:ok, fixture})

      assert {:ok, balance} = Balances.get(client, "EUR")
      assert balance["currency"] == "EUR"
      assert balance["amount"] == "10000.00"
    end

    test "upcases the currency code before requesting", %{client: client} do
      fixture = balance_fixture("GBP")
      MockHTTP.put_response("/v2/balances/GBP", {:ok, fixture})

      assert {:ok, balance} = Balances.get(client, "gbp")
      assert balance["currency"] == "GBP"
    end

    test "returns AuthenticationError on 401", %{client: client} do
      alias CurrencycloudClient.Error.AuthenticationError

      MockHTTP.put_response(
        "/v2/balances/EUR",
        {:error,
         %AuthenticationError{
           request: %{verb: "GET", url: "", params: %{}},
           response: %{status_code: 401, request_id: nil, date: nil},
           errors: []
         }}
      )

      assert {:error, %AuthenticationError{}} = Balances.get(client, "EUR")
    end
  end

  describe "find/2" do
    test "returns all balances with pagination", %{client: client} do
      response = %{
        "balances" => [balance_fixture("EUR"), balance_fixture("GBP")],
        "pagination" => %{
          "total_entries" => 2,
          "total_pages" => 1,
          "current_page" => 1,
          "per_page" => 25,
          "previous_page" => -1,
          "next_page" => -1
        }
      }

      MockHTTP.put_response("/v2/balances/find", {:ok, response})

      assert {:ok, result} = Balances.find(client)
      assert length(result["balances"]) == 2
      assert result["pagination"]["total_entries"] == 2
    end

    test "passes filter params through", %{client: client} do
      MockHTTP.put_response("/v2/balances/find", {:ok, %{"balances" => [], "pagination" => %{}}})
      assert {:ok, _} = Balances.find(client, %{"scope" => "non_zero", "per_page" => 10})
    end
  end

  describe "top_up_margin/2" do
    test "posts to top_up_margin endpoint", %{client: client} do
      MockHTTP.put_response(
        "/v2/balances/top_up_margin",
        {:ok, %{"amount" => "1000.00", "currency" => "EUR"}}
      )

      assert {:ok, result} =
               Balances.top_up_margin(client, %{"currency" => "EUR", "amount" => "1000.00"})

      assert result["currency"] == "EUR"
    end
  end
end

defmodule CurrencycloudClient.API.ConversionsTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Conversions
  alias CurrencycloudClient.Test.MockHTTP

  setup do
    {:ok, client: build_client()}
  end

  describe "create/2" do
    test "creates a conversion and returns the entity", %{client: client} do
      fixture = conversion_fixture()
      MockHTTP.put_response("/v2/conversions/create", {:ok, fixture})

      params = %{
        "buy_currency" => "EUR",
        "sell_currency" => "GBP",
        "fixed_side" => "buy",
        "amount" => "10000.00",
        "term_agreement" => "true"
      }

      assert {:ok, conversion} = Conversions.create(client, params)
      assert conversion["buy_currency"] == "EUR"
      assert conversion["sell_currency"] == "GBP"
      assert conversion["status"] == "awaiting_funds"
    end
  end

  describe "get/2" do
    test "retrieves a conversion by id", %{client: client} do
      fixture = conversion_fixture(%{"id" => "conv-123"})
      MockHTTP.put_response("/v2/conversions/conv-123", {:ok, fixture})

      assert {:ok, conversion} = Conversions.get(client, "conv-123")
      assert conversion["id"] == "conv-123"
    end
  end

  describe "find/2" do
    test "returns paginated conversions", %{client: client} do
      response = %{
        "conversions" => [conversion_fixture()],
        "pagination" => %{"total_entries" => 1, "current_page" => 1}
      }

      MockHTTP.put_response("/v2/conversions/find", {:ok, response})
      assert {:ok, result} = Conversions.find(client, %{"status" => "awaiting_funds"})
      assert length(result["conversions"]) == 1
    end
  end

  describe "split/3" do
    test "splits a conversion by amount", %{client: client} do
      split_response = %{
        "parent_conversion" => conversion_fixture(%{"client_buy_amount" => "8000.00"}),
        "child_conversion" => conversion_fixture(%{"client_buy_amount" => "2000.00"})
      }

      MockHTTP.put_response("/v2/conversions/conv-abc/split", {:ok, split_response})
      assert {:ok, result} = Conversions.split(client, "conv-abc", "2000.00")
      assert result["child_conversion"]["client_buy_amount"] == "2000.00"
    end
  end

  describe "cancel/2" do
    test "cancels a conversion", %{client: client} do
      fixture = conversion_fixture(%{"status" => "cancelled"})
      MockHTTP.put_response("/v2/conversions/conv-xyz/cancel", {:ok, fixture})

      assert {:ok, conversion} = Conversions.cancel(client, "conv-xyz")
      assert conversion["status"] == "cancelled"
    end
  end
end

defmodule CurrencycloudClient.API.PaymentsTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Payments
  alias CurrencycloudClient.Test.MockHTTP

  setup do
    {:ok, client: build_client()}
  end

  describe "create/2" do
    test "creates a payment", %{client: client} do
      fixture = payment_fixture()
      MockHTTP.put_response("/v2/payments/create", {:ok, fixture})

      params = %{
        "currency" => "EUR",
        "beneficiary_id" => uuid(),
        "amount" => "10000.00",
        "reason" => "Invoice",
        "reference" => "INV-001"
      }

      assert {:ok, payment} = Payments.create(client, params)
      assert payment["currency"] == "EUR"
      assert payment["status"] == "ready_to_send"
    end
  end

  describe "validate/2" do
    test "validates without SCA requirement", %{client: client} do
      response = %{"id" => uuid(), "sca" => %{"required" => false}}
      MockHTTP.put_response("/v2/payments/validate", {:ok, response})

      assert {:ok, result} = Payments.validate(client, %{"currency" => "EUR"})
      assert result["sca"]["required"] == false
    end

    test "validates with SCA requirement", %{client: client} do
      response = %{
        "id" => uuid(),
        "sca" => %{"required" => true, "id" => "sca-123", "type" => "SMS"}
      }

      MockHTTP.put_response("/v2/payments/validate", {:ok, response})

      assert {:ok, result} = Payments.validate(client, %{"currency" => "EUR"})
      assert result["sca"]["required"] == true
      assert result["sca"]["type"] == "SMS"
    end
  end

  describe "authorise/2" do
    test "authorises a list of payment IDs", %{client: client} do
      ids = [uuid(), uuid()]

      response = %{
        "authorised_payments" =>
          Enum.map(ids, &%{"id" => &1, "authorisation_steps_required" => 0}),
        "not_authorised_payments" => []
      }

      MockHTTP.put_response("/v2/payments/authorise", {:ok, response})

      assert {:ok, result} = Payments.authorise(client, ids)
      assert length(result["authorised_payments"]) == 2
    end
  end

  describe "delete/2" do
    test "deletes a pending payment", %{client: client} do
      fixture = payment_fixture(%{"status" => "deleted"})
      MockHTTP.put_response("/v2/payments/delete/pay-123", {:ok, fixture})

      assert {:ok, payment} = Payments.delete(client, "pay-123")
      assert payment["status"] == "deleted"
    end
  end
end

defmodule CurrencycloudClient.API.BeneficiariesTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Beneficiaries
  alias CurrencycloudClient.Test.MockHTTP

  setup do
    {:ok, client: build_client()}
  end

  describe "create/2" do
    test "creates a beneficiary", %{client: client} do
      fixture = beneficiary_fixture()
      MockHTTP.put_response("/v2/beneficiaries/create", {:ok, fixture})

      params = %{
        "bank_account_holder_name" => "ACME GmbH",
        "bank_country" => "DE",
        "currency" => "EUR",
        "iban" => "DE89370400440532013000",
        "payment_types" => ["regular"]
      }

      assert {:ok, b} = Beneficiaries.create(client, params)
      assert b["bank_account_holder_name"] == "ACME GmbH"
      assert b["currency"] == "EUR"
    end
  end

  describe "validate/2" do
    test "validates beneficiary without saving", %{client: client} do
      fixture = beneficiary_fixture()
      MockHTTP.put_response("/v2/beneficiaries/validate", {:ok, fixture})

      assert {:ok, b} =
               Beneficiaries.validate(client, %{
                 "bank_account_holder_name" => "ACME GmbH",
                 "bank_country" => "DE",
                 "currency" => "EUR"
               })

      assert b["bank_account_holder_name"] == "ACME GmbH"
    end
  end

  describe "delete/2" do
    test "deletes a beneficiary", %{client: client} do
      fixture = beneficiary_fixture(%{"id" => "ben-123"})
      MockHTTP.put_response("/v2/beneficiaries/delete/ben-123", {:ok, fixture})

      assert {:ok, b} = Beneficiaries.delete(client, "ben-123")
      assert b["id"] == "ben-123"
    end
  end
end

defmodule CurrencycloudClient.API.ReferenceTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.Factory

  alias CurrencycloudClient.API.Reference
  alias CurrencycloudClient.Test.MockHTTP

  setup do
    {:ok, client: build_client()}
  end

  describe "get_available_currencies/1" do
    test "returns a list of currencies", %{client: client} do
      response = %{
        "currencies" => [
          %{
            "code" => "GBP",
            "decimal_places" => 2,
            "name" => "British Pound",
            "online_trading" => true
          },
          %{"code" => "EUR", "decimal_places" => 2, "name" => "Euro", "online_trading" => true}
        ]
      }

      MockHTTP.put_response("/v2/reference/currencies", {:ok, response})
      assert {:ok, result} = Reference.get_available_currencies(client)
      assert length(result["currencies"]) == 2
    end
  end

  describe "get_beneficiary_required_details/2" do
    test "returns required fields for EUR/DE", %{client: client} do
      response = %{
        "details" => [
          %{
            "payment_type" => "regular",
            "required_fields" => [
              %{"name" => "iban", "required" => true},
              %{"name" => "bic_swift", "required" => true}
            ]
          }
        ]
      }

      MockHTTP.put_response("/v2/reference/beneficiary_required_details", {:ok, response})

      assert {:ok, result} =
               Reference.get_beneficiary_required_details(client, %{
                 "currency" => "EUR",
                 "bank_account_country" => "DE"
               })

      assert length(result["details"]) == 1
    end
  end

  describe "get_bank_details/2" do
    test "returns bank details by IBAN", %{client: client} do
      response = %{
        "bank_name" => "Commerzbank",
        "bank_address" => "Frankfurt",
        "bank_country" => "DE"
      }

      MockHTTP.put_response("/v2/reference/bank_details", {:ok, response})

      assert {:ok, result} =
               Reference.get_bank_details(client, %{
                 "identifier_type" => "iban",
                 "identifier_value" => "DE89370400440532013000"
               })

      assert result["bank_name"] == "Commerzbank"
    end
  end
end
