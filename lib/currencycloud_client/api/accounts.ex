defmodule CurrencycloudClient.API.Accounts do
  @moduledoc """
  Accounts API — create and manage sub-accounts.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `create/2` | POST | `/v2/accounts/create` |
  | `get/2` | GET | `/v2/accounts/{id}` |
  | `update/3` | POST | `/v2/accounts/update/{id}` |
  | `find/2` | POST | `/v2/accounts/find` |
  | `current/1` | GET | `/v2/accounts/current` |
  | `get_compliance_settings/2` | GET | `/v2/accounts/{id}/compliance_settings` |
  | `update_compliance_settings/3` | POST | `/v2/accounts/{id}/compliance_settings` |
  | `get_payment_charges_settings/2` | GET | `/v2/accounts/{id}/payment_charges_settings` |
  | `manage_payment_charges_settings/3` | POST | `/v2/accounts/{id}/payment_charges_settings` |
  | `accept_terms_of_use/2` | POST | `/v2/accounts/{id}/terms_and_conditions/accept` |

  ## Example

      # Create a new sub-account
      {:ok, account} = CurrencycloudClient.API.Accounts.create(client, %{
        account_name: "Acme GmbH",
        legal_entity_type: "company",
        country: "DE",
        city: "Berlin"
      })

      # Get a sub-account
      {:ok, account} = CurrencycloudClient.API.Accounts.get(client, account["id"])

      # Find all enabled accounts
      {:ok, result} = CurrencycloudClient.API.Accounts.find(client, %{status: "enabled"})
      accounts = result["accounts"]
      pagination = result["pagination"]
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new sub-account.

  ## Required params
  - `account_name` – The name of the account.
  - `legal_entity_type` – `"company"` or `"individual"`.

  ## Optional params
  - `your_reference`, `status`, `street`, `city`, `state_or_province`,
    `country`, `postal_code`, `spread_table`, `identification_type`,
    `identification_value`, `terms_and_conditions_accepted`
  """
  @spec create(Client.t(), map()) :: Types.result(Types.account())
  def create(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/accounts/create", stringify(params))
    end)
  end

  # ---------------------------------------------------------------------------
  # Get
  # ---------------------------------------------------------------------------

  @doc "Retrieves a sub-account by UUID."
  @spec get(Client.t(), Types.uuid()) :: Types.result(Types.account())
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/accounts/#{id}", %{})
    end)
  end

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------

  @doc """
  Updates a sub-account. Returns the updated account entity on success.
  Cannot change the `legal_entity_type`.
  """
  @spec update(Client.t(), Types.uuid(), map()) :: Types.result(Types.account())
  def update(%Client{} = client, id, params) when is_binary(id) and is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/accounts/update/#{id}", stringify(params))
    end)
  end

  # ---------------------------------------------------------------------------
  # Find
  # ---------------------------------------------------------------------------

  @doc """
  Finds accounts matching the given filter criteria.

  Returns `{:ok, %{"accounts" => [...], "pagination" => %{...}}}`.

  ## Filter params
  - `account_name`, `brand`, `your_reference`, `status`, `street`, `city`,
    `state_or_province`, `country`, `postal_code`, `spread_table`
  - Pagination: `page`, `per_page`, `order`, `order_asc_desc`
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/accounts/find", stringify(params))
    end)
  end

  # ---------------------------------------------------------------------------
  # Current (authenticating account)
  # ---------------------------------------------------------------------------

  @doc "Returns the main account of the authenticated user."
  @spec current(Client.t()) :: Types.result(Types.account())
  def current(%Client{} = client) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/accounts/current", %{})
    end)
  end

  # ---------------------------------------------------------------------------
  # Compliance settings
  # ---------------------------------------------------------------------------

  @doc "Gets the compliance settings for the account with the given ID."
  @spec get_compliance_settings(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def get_compliance_settings(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/accounts/#{id}/compliance_settings", %{})
    end)
  end

  @doc "Updates compliance settings for a sub-account."
  @spec update_compliance_settings(Client.t(), Types.uuid(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def update_compliance_settings(%Client{} = client, id, params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/accounts/#{id}/compliance_settings", stringify(params))
    end)
  end

  # ---------------------------------------------------------------------------
  # Payment charges settings
  # ---------------------------------------------------------------------------

  @doc "Retrieves the payment charges settings for the given account."
  @spec get_payment_charges_settings(Client.t(), Types.uuid()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_payment_charges_settings(%Client{} = client, id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/accounts/#{id}/payment_charges_settings", %{})
    end)
  end

  @doc "Manages payment charge settings (enable, disable, set as default) for an account."
  @spec manage_payment_charges_settings(Client.t(), Types.uuid(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def manage_payment_charges_settings(%Client{} = client, id, params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/accounts/#{id}/payment_charges_settings", stringify(params))
    end)
  end

  # ---------------------------------------------------------------------------
  # Terms of use (Outsourced KYC)
  # ---------------------------------------------------------------------------

  @doc "Accepts the Terms of Use for accounts using the Outsourced KYC model."
  @spec accept_terms_of_use(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def accept_terms_of_use(%Client{} = client, id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/accounts/#{id}/terms_and_conditions/accept", %{})
    end)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp stringify(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
  end
end
