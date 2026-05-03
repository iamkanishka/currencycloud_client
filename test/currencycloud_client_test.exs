defmodule CurrencycloudClientTest do
  use ExUnit.Case, async: true

  import CurrencycloudClient.Test.Factory

  describe "on_behalf_of/3" do
    test "calls fun with scoped client and returns result" do
      client = build_client()
      contact_id = uuid()

      result =
        CurrencycloudClient.on_behalf_of(client, contact_id, fn sub ->
          assert sub.on_behalf_of == contact_id
          {:ok, :scoped}
        end)

      assert {:ok, :scoped} = result
    end

    test "propagates errors from the inner function" do
      client = build_client()

      result =
        CurrencycloudClient.on_behalf_of(client, uuid(), fn _sub ->
          {:error, :some_error}
        end)

      assert {:error, :some_error} = result
    end

    test "clears on_behalf_of for nested calls" do
      client = build_client()
      outer_id = uuid()

      CurrencycloudClient.on_behalf_of(client, outer_id, fn sub ->
        assert sub.on_behalf_of == outer_id
        {:ok, sub}
      end)

      # Original client is unchanged
      assert client.on_behalf_of == nil
    end
  end

  describe "default_client/0" do
    test "raises when DefaultSession is not running" do
      assert_raise RuntimeError, ~r/DefaultSession is not running/, fn ->
        CurrencycloudClient.default_client()
      end
    end
  end
end
