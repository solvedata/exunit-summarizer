defmodule ExunitSummarizer.MixProject do
  use Mix.Project

  def project do
    [
      app: :exunit_summarizer,
      version: "0.1.0",
      elixir: "~>1.11.0 or ~>1.12.0 or ~>1.13.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.2"}
    ]
  end
end
