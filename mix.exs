defmodule CurrencycloudClient.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/iamkanishka/currencycloud_client"

  def project do
    [
      app: :currencycloud_client,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Production-grade Elixir client for the Currencycloud v2 API",
      package: package(),
      name: "CurrencycloudClient",
      source_url: @source_url,
      homepage_url: "https://developer.currencycloud.com",
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {CurrencycloudClient.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # ── Runtime ──────────────────────────────────────────────────────────
      {:finch, "~> 0.18.0"},
      {:mint, "~> 1.7.1"},
      {:castore, "~> 1.0.9"},
      {:nimble_pool, "~> 1.1.0"},
      {:hpax, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:nimble_options, "~> 1.1"},

      # ── Dev / Test ───────────────────────────────────────────────────────
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:earmark_parser, "~> 1.4", runtime: false},
      {:makeup, "~> 1.2", runtime: false},
      {:makeup_elixir, "~> 1.0", runtime: false},
      {:makeup_erlang, "~> 1.0", runtime: false},
      {:nimble_parsec, "~> 1.4", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:bunt, "~> 1.0", runtime: false},
      {:file_system, "~> 1.1", runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:bypass, "~> 2.1", only: :test, runtime: false},
      {:plug, "~> 1.16", only: :test},
      {:plug_cowboy, "~> 2.6", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:plug_crypto, "~> 2.1", only: :test},
      {:cowboy, "~> 2.7", only: :test},
      {:cowboy_telemetry, "~> 0.4", only: :test},
      {:cowlib, "~> 2.12", only: :test},
      {:ranch, "~> 1.8", only: :test},
      {:mime, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      quality: ["format --check-formatted", "credo --strict"],
      "test.coverage": ["coveralls.html"]
    ]
  end

  defp package do
    [
      maintainers: ["Kanishka Naik"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Currencycloud Docs" => "https://developer.currencycloud.com"
      },
      files: ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Core: [
          CurrencycloudClient,
          CurrencycloudClient.Client,
          CurrencycloudClient.Config,
          CurrencycloudClient.Session
        ],
        API: [
          CurrencycloudClient.API.Authentication,
          CurrencycloudClient.API.Accounts,
          CurrencycloudClient.API.Balances,
          CurrencycloudClient.API.Beneficiaries,
          CurrencycloudClient.API.Contacts,
          CurrencycloudClient.API.Conversions,
          CurrencycloudClient.API.Funding,
          CurrencycloudClient.API.Payments,
          CurrencycloudClient.API.Payers,
          CurrencycloudClient.API.Rates,
          CurrencycloudClient.API.Reference,
          CurrencycloudClient.API.Reporting,
          CurrencycloudClient.API.Transactions,
          CurrencycloudClient.API.Transfers,
          CurrencycloudClient.API.WithdrawalAccounts
        ],
        Infrastructure: [
          CurrencycloudClient.HTTP,
          CurrencycloudClient.FinchPool,
          CurrencycloudClient.RetryStrategy,
          CurrencycloudClient.Telemetry
        ],
        "Types & Errors": [
          CurrencycloudClient.Types,
          CurrencycloudClient.Error
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:mix, :jason, :finch, :ex_unit, :bypass],
      flags: [:error_handling, :underspecs],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end
end
