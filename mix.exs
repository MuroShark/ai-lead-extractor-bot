defmodule LeadBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :lead_bot,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_local_path: "priv/plts",
        flags: [:error_handling, :unmatched_returns, :extra_return]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LeadBot.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_gram, "~> 0.67"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:rustler, "~> 0.38"},
      {:dotenvy, "~> 1.1"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
