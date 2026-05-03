ExUnit.start(exclude: [:integration])
# Start MockSession as a named process available to all unit tests that use build_client/0
{:ok, _} =
  CurrencycloudClient.Test.MockSession.start_link(name: CurrencycloudClient.Test.MockSession)
