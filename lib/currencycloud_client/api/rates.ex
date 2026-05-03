defmodule CurrencycloudClient.API.Rates do
  @moduledoc """
  Rates API — retrieve FX rates.

  ## Two rate types

  - **Basic rates** (`get_basic/2`) — indicative rates for multiple currency pairs
    in a single call. Good for live tickers and UX previews. Not tradeable.
  - **Detailed rates** (`get_detailed/2`) — a single firm quote based on your
    account's spread table. Call immediately before `Conversions.create/2`.

  ## Endpoints covered

  | Function | Method | Path |
  |---|---|---|
  | `get_basic/2` | GET | `/v2/rates/find` |
  | `get_detailed/2` | GET | `/v2/rates/detailed` |

  ## Example

      # Indicative rates for a basket of pairs
      {:ok, result} = CurrencycloudClient.API.Rates.get_basic(client, %{
        currency_pair: "GBPEUR,USDGBP,EURUSD"
      })

      # Detailed (tradeable) quote for booking a conversion
      {:ok, rate} = CurrencycloudClient.API.Rates.get_detailed(client, %{
        buy_currency: "EUR",
        sell_currency: "GBP",
        fixed_side: "buy",
        amount: "10000.00"
      })
      IO.puts("Client rate: \#{rate["client_rate"]}")
      IO.puts("Settlement cutoff: \#{rate["settlement_cut_off_time"]}")
  """

  alias CurrencycloudClient.Client
  alias CurrencycloudClient.Error
  alias CurrencycloudClient.RetryStrategy
  alias CurrencycloudClient.Types

  @doc """
  Returns indicative (non-tradeable) rates for one or more currency pairs.

  ## Required params
  - `currency_pair` – Comma-separated list of 6-char pairs, e.g. `"GBPEUR,USDGBP"`.

  ## Optional params
  - `ignore_invalid_pairs` – `true` to skip unknown pairs rather than error.
  """
  @spec get_basic(Client.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def get_basic(%Client{} = client, params) when is_map(params) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/rates/find", stringify(params))
    end)
  end

  @doc """
  Returns a detailed (firm) rate quote for a single currency pair.

  This is the rate used to book a conversion. Call it immediately before
  `CurrencycloudClient.API.Conversions.create/2` to minimise slippage.

  ## Required params
  - `buy_currency` – ISO 4217 code for the currency to buy.
  - `sell_currency` – ISO 4217 code for the currency to sell.
  - `fixed_side` – `"buy"` or `"sell"` — which side of the trade is fixed.
  - `amount` – The amount on the fixed side.

  ## Optional params
  - `conversion_date` – ISO 8601 date; defaults to next available value date.
  - `on_behalf_of` – Contact UUID for sub-account scoping.
  """
  @spec get_detailed(Client.t(), map()) :: Types.result(Types.rate())
  def get_detailed(
        %Client{} = client,
        %{"buy_currency" => _, "sell_currency" => _, "fixed_side" => _, "amount" => _} = params
      ) do
    RetryStrategy.with_retry(client.config, fn ->
      Client.get(client, "/v2/rates/detailed", stringify(params))
    end)
  end

  defp stringify(params) when is_map(params) do
    params |> Enum.map(fn {k, v} -> {to_string(k), v} end) |> Map.new()
  end
end
