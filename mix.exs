defmodule ExunitSummarizer.MixProject do
  use Mix.Project

  def project do
    [
      app: :exunit_summarizer,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"}
    ]
  end

  defp aliases do
    [
      "test.report.clean": "run priv/clean.exs",
      "test.report": "run priv/report.exs"
    ]
  end
end
