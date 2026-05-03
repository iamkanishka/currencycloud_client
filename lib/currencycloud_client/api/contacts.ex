defmodule CurrencycloudClient.API.Contacts do
  @moduledoc """
  Contacts API — manage contacts (people) associated with accounts.

  A Contact is the sub-account user record. It must be created before any
  `on_behalf_of` activity is undertaken for that sub-account.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `create/2` | POST | `/v2/contacts/create` |
  | `get/2` | GET | `/v2/contacts/{id}` |
  | `update/3` | POST | `/v2/contacts/update/{id}` |
  | `find/2` | POST | `/v2/contacts/find` |
  | `current/1` | GET | `/v2/contacts/current` |
  | `generate_hmac_key/2` | POST | `/v2/contacts/{id}/generate_hmac_key` |

  ## Example

      {:ok, contact} = CurrencycloudClient.API.Contacts.create(client, %{
        account_id: account["id"],
        first_name: "Alice",
        last_name: "Müller",
        email_address: "alice@example.com",
        phone_number: "+49301234567",
        country: "DE",
        date_of_birth: "1985-06-15",
        expected_countries_of_operation: ["DE", "FR"],
        base_currency: "EUR",
        status: "enabled"
      })
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc """
  Creates a new contact. The `account_id`, `first_name`, `last_name`,
  `email_address`, and `phone_number` fields are required.
  """
  @spec create(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def create(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/contacts/create", stringify(params))
    end)
  end

  @doc "Retrieves a contact by UUID."
  @spec get(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def get(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/contacts/#{id}", %{})
    end)
  end

  @doc "Updates a contact. Returns the updated contact entity."
  @spec update(Client.t(), Types.uuid(), map()) :: {:ok, map()} | {:error, Error.t()}
  def update(%Client{} = client, id, params) when is_binary(id) and is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/contacts/update/#{id}", stringify(params))
    end)
  end

  @doc """
  Finds contacts matching the given filter criteria.

  Returns `{:ok, %{"contacts" => [...], "pagination" => %{...}}}`.

  ## Filter params
  - `account_id`, `first_name`, `last_name`, `email_address`, `status`
  - Pagination: `page`, `per_page`, `order`, `order_asc_desc`
  """
  @spec find(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def find(%Client{} = client, params \\ %{}) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/contacts/find", stringify(params))
    end)
  end

  @doc "Returns the contact record for the currently authenticated user."
  @spec current(Client.t()) :: {:ok, map()} | {:error, Error.t()}
  def current(%Client{} = client) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/contacts/current", %{})
    end)
  end

  @doc """
  Generates an HMAC key for webhook signature verification for a contact.
  Store the returned key securely — it is only shown once.
  """
  @spec generate_hmac_key(Client.t(), Types.uuid()) :: {:ok, map()} | {:error, Error.t()}
  def generate_hmac_key(%Client{} = client, id) when is_binary(id) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.post(client, "/v2/contacts/#{id}/generate_hmac_key", %{})
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
