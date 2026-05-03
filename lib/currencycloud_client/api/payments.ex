defmodule CurrencycloudClient.API.Payments do
  @moduledoc """
  Payments API — create, manage, and track outbound payments.

  This is the most feature-rich group in the Currencycloud API.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `create/2` | POST | `/v2/payments/create` |
  | `get/2` | GET | `/v2/payments/{id}` |
  | `find/2` | POST | `/v2/payments/find` |
  | `update/3` | POST | `/v2/payments/update/{id}` |
  | `delete/2` | POST | `/v2/payments/delete/{id}` |
  | `validate/2` | POST | `/v2/payments/validate` |
  | `authorise/2` | POST | `/v2/payments/authorise` |
  | `get_confirmation/2` | GET | `/v2/payments/{id}/confirmation` |
  | `get_submission/2` | GET | `/v2/payments/{id}/submission` |
  | `get_tracking/2` | GET | `/v2/payments/{id}/tracking_info` |
  | `get_delivery_date/2` | GET | `/v2/payments/payment_delivery_date` |
  | `quote_fee/2` | POST | `/v2/payments/fee_collection_quotes` |
  | `get_fee_rules/2` | GET | `/v2/payments/fee_collection_rules` |
  | `assign_fee_rule/2` | POST | `/v2/payments/fee_collection_rules` |
  | `unassign_fee_rule/2` | POST | `/v2/payments/fee_collection_rules/delete` |
  | `resend_notification/2` | POST | `/v2/payments/{id}/resend_notification` |

  ## Strong Customer Authentication (SCA)

  Accounts enrolled in SCA must call `validate/2` before `create/2`.
  If the response includes header `x-sca-required: true`, the API sends
  an OTP via SMS. Pass the OTP in the subsequent `create/2` call as the
  `x-sca-token` header. This library surfaces SCA metadata in the response
  map under the `"sca"` key.

  ## Example

      # Validate (triggers SCA OTP if applicable)
      {:ok, validated} = CurrencycloudClient.API.Payments.validate(client, payment_params)

      # Check for SCA requirement
      if validated["sca"]["required"] do
        otp = get_otp_from_user()  # prompt the user
        payment_params = Map.put(payment_params, "sca_token", otp)
                         |> Map.put("sca_id", validated["sca"]["id"])
      end

      # Create the payment
      {:ok, payment} = CurrencycloudClient.API.Payments.create(client, payment_params)
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc """
  Creates an outbound payment.

  ## Required params
  - `currency` – Payment currency.
  - `beneficiary_id` – UUID of the recipient beneficiary.
  - `amount` – Payment amount as a string.
  - `reason` – Purpose of payment.
  - `reference` – Your reference (shown on beneficiary's bank statement).

  ## Optional params
  - `payment_date`, `payment_type` (`"regular"` or `"priority"`),
    `conversion_id`, `payer_details_source`, `payer_entity_type`,
    `payer_company_name`, `payer_first_name`, `payer_last_name`,
    `payer_city`, `payer_country`, `payer_date_of_birth`,
    `payer_identification_type`, `payer_identification_value`,
    `unique_request_id`, `ultimate_beneficiary_name`, `purpose_code`,
    `charge_type`, `fee_currency`, `fee_amount`, `on_behalf_of`
  """
  @spec create(Client.t(), map()) :: Types.result(Types.payment())
  def create(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/create", stringify(params))
    end)
  end

  @doc "Retrieves a payment by UUID."
  @spec get(Client.t(), Types.uuid()) :: Types.result(Types.payment())
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/payments/#{id}", %{})
    end)
  end

  @doc """
  Finds payments matching the given filter criteria.

  Returns `{:ok, %{"payments" => [...], "pagination" => %{...}}}`.

  ## Filter params
  - `short_reference`, `currency`, `amount_from`, `amount_to`, `status`,
    `reason`, `payment_date_from`, `payment_date_to`, `transferred_at_from`,
    `transferred_at_to`, `created_at_from`, `created_at_to`,
    `updated_at_from`, `updated_at_to`, `beneficiary_id`, `conversion_id`,
    `payment_group_id`, `unique_request_id`, `scope`
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/find", stringify(params))
    end)
  end

  @doc "Updates a payment. Only pending payments can be updated."
  @spec update(Client.t(), Types.uuid(), map()) :: Types.result(Types.payment())
  def update(%Client{} = client, id, params) when is_binary(id) and is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/update/#{id}", stringify(params))
    end)
  end

  @doc "Deletes a pending payment. Cannot delete payments that are in-flight."
  @spec delete(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def delete(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/delete/#{id}", %{})
    end)
  end

  @doc """
  Validates payment details without creating the payment.

  If your account is enrolled in SCA, this call may trigger an OTP via SMS
  and the response will include `sca` metadata:

      %{
        "sca" => %{
          "required" => true,
          "id" => "sca-uuid",
          "type" => "SMS"
        }
      }

  Pass `sca_id` and `sca_token` (the OTP) in the subsequent `create/2` call.
  """
  @spec validate(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def validate(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/validate", stringify(params))
    end)
  end

  @doc """
  Authorises one or more payments (multi-step authorisation flow).

  ## Required params
  - `payment_ids` – List of payment UUIDs to authorise.
  """
  @spec authorise(Client.t(), [Types.uuid()]) :: {:ok, map()} | {:error, Error.t()}
  def authorise(%Client{} = client, payment_ids) when is_list(payment_ids) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/authorise", %{"payment_ids" => payment_ids})
    end)
  end

  @doc """
  Returns the settlement confirmation for a completed payment.
  Only available after the payment status transitions to `completed`.
  """
  @spec get_confirmation(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def get_confirmation(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/payments/#{id}/confirmation", %{})
    end)
  end

  @doc """
  Returns the SWIFT submission information for a payment (MT103 / pacs.008).
  Only available for priority (SWIFT) payments after submission.
  """
  @spec get_submission(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def get_submission(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/payments/#{id}/submission", %{})
    end)
  end

  @doc """
  Returns live tracking information for a payment as it moves through
  the correspondent banking network.
  """
  @spec get_tracking(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def get_tracking(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/payments/#{id}/tracking_info", %{})
    end)
  end

  @doc """
  Returns the expected delivery date for a payment.

  ## Required params
  - `payment_date` – ISO 8601 date.
  - `payment_type` – `"regular"` or `"priority"`.
  - `currency` – Payment currency.
  - `bank_country` – Beneficiary bank country.
  """
  @spec get_delivery_date(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_delivery_date(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/payments/payment_delivery_date", stringify(params))
    end)
  end

  @doc """
  Returns a fee quote for the given payment parameters.
  """
  @spec quote_fee(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def quote_fee(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/fee_collection_quotes", stringify(params))
    end)
  end

  @doc "Returns the fee collection rules configured for the account."
  @spec get_fee_rules(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_fee_rules(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/payments/fee_collection_rules", stringify(params))
    end)
  end

  @doc "Assigns a fee rule to an account or sub-account."
  @spec assign_fee_rule(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def assign_fee_rule(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/fee_collection_rules", stringify(params))
    end)
  end

  @doc "Removes a fee rule assignment from an account."
  @spec unassign_fee_rule(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def unassign_fee_rule(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/fee_collection_rules/delete", stringify(params))
    end)
  end

  @doc """
  Re-fires the webhook/email notification for a specific payment.

  Useful when a webhook delivery failed or an integration needs to reprocess.
  """
  @spec resend_notification(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def resend_notification(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/payments/#{id}/resend_notification", %{})
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
