defmodule Mix.Tasks.Test.Report.Clean do
  @recursive false
  @preferred_cli_env :test

  @shortdoc "Generate a summarized ExUnit report"

  use Mix.Task

  @impl Mix.Task
  def run(_) do
    if Mix.env() != :test && !System.get_env("MIX_ENV") do
      Mix.env(:test)

      Mix.shell().error("""
      "mix test.report" is running in the \"#{Mix.env()}\" environment. The
       environment should match the environment used to run tests. You
       should set the "MIX_ENV" environment variable explicitly to avoid
       this error.
      Assuming that this was a mistake and setting "MIX_ENV" to "test".
      """)
    end

    ExunitSummarizer.ReportFiles.clean_all_report_files()
  end
end
