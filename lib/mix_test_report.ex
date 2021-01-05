defmodule Mix.Tasks.Test.Report do
  @recursive false
  @preferred_cli_env :test

  @shortdoc "Generate a summarized ExUnit report"

  use Mix.Task

  @impl Mix.Task
  def run(_) do
    unless System.get_env("MIX_ENV") || Mix.env() == :test do
      Mix.env(:test)

      Mix.shell().error("""
      "mix test.report" is running in the \"#{Mix.env()}\" environment. If you are \
      running tests from within another command, you can either:
        1. set MIX_ENV explicitly:
            MIX_ENV=test mix test.another
        2. set the :preferred_cli_env for the command inside "def project" in your mix.exs:
            preferred_cli_env: ["test.report": :test]
      """)
    end

    case ExunitSummarizer.Utils.generate_report() do
      {:ok, output} ->
        Mix.shell().info(output)

      {:error, output} ->
        Mix.shell().error(output)
        Mix.raise("One or more tests in the report failed.")
    end
  end
end
