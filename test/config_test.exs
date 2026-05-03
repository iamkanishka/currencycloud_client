defmodule CurrencycloudClient.ConfigTest do
  use ExUnit.Case, async: true
  doctest CurrencycloudClient.Config

  alias CurrencycloudClient.Config

  describe "new!/1" do
    test "creates a valid config with required fields" do
      config = Config.new!(environment: :demo, login_id: "user@example.com", api_key: "key123")

      assert config.environment == :demo
      assert config.login_id == "user@example.com"
      assert config.api_key == "key123"
      assert config.base_url == "https://devapi.currencycloud.com"
      assert config.timeout == 30_000
      assert config.max_retries == 5
    end

    test "sets production base_url for :production environment" do
      config = Config.new!(environment: :production, login_id: "u@e.com", api_key: "k")
      assert config.base_url == "https://api.currencycloud.com"
    end

    test "accepts custom timeout and retry options" do
      config =
        Config.new!(
          environment: :demo,
          login_id: "u@e.com",
          api_key: "k",
          timeout: 10_000,
          max_retries: 3,
          retry_base_delay: 200
        )

      assert config.timeout == 10_000
      assert config.max_retries == 3
      assert config.retry_base_delay == 200
    end

    test "raises NimbleOptions.ValidationError on missing required fields" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(environment: :demo)
      end
    end

    test "raises NimbleOptions.ValidationError on invalid environment" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(environment: :staging, login_id: "u@e.com", api_key: "k")
      end
    end

    test "raises NimbleOptions.ValidationError on negative timeout" do
      assert_raise NimbleOptions.ValidationError, fn ->
        Config.new!(environment: :demo, login_id: "u@e.com", api_key: "k", timeout: -1)
      end
    end
  end

  describe "base_url/1" do
    test "returns the configured base URL" do
      config = Config.new!(environment: :demo, login_id: "u@e.com", api_key: "k")
      assert Config.base_url(config) == "https://devapi.currencycloud.com"
    end
  end
end
