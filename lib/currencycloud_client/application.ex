defmodule CurrencycloudClient.Application do
  @moduledoc """
  OTP Application entry point for `currencycloud_client`.

  When `manage_session: true` is set in application config, this supervisor
  automatically starts both the `FinchPool` (HTTP connection pool) and a
  `Session` GenServer for the configured credentials.

  For most production integrations, add children to your own supervisor:

      children = [
        {CurrencycloudClient.FinchPool, config: config, name: MyApp.CCPool},
        {CurrencycloudClient.Session,   config: config, name: MyApp.CCSession}
      ]
  """

  use Application

  @impl Application
  def start(_type, _args) do
    children = maybe_managed_children()
    opts = [strategy: :one_for_one, name: CurrencycloudClient.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_managed_children do
    if Application.get_env(:currencycloud_client, :manage_session, false) do
      config = CurrencycloudClient.Config.from_application_env()

      [
        {CurrencycloudClient.FinchPool,
         config: config, name: CurrencycloudClient.DefaultFinchSupervisor},
        {CurrencycloudClient.Session, config: config, name: CurrencycloudClient.DefaultSession}
      ]
    else
      []
    end
  end
end
