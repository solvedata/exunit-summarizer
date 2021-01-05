defmodule ExunitSummarizer do
  use GenServer

  @impl true
  def init(_opts) do
    {:ok, []}
  end

  @impl true
  def handle_cast({:suite_finished, _run_us, _load_us}, test_cases) do
    write_report(test_cases)

    {:noreply, test_cases}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, test_cases) do
    test_cases = [test | test_cases]

    {:noreply, test_cases}
  end

  def handle_cast(_event, test_cases), do: {:noreply, test_cases}

  def write_report(test_cases) do
    if Application.get_env(:exunit_json_formatter, :generate_report_file?, true) do
      # Reverse the list as test cases are added to the front of the list.
      suites =
        test_cases
        |> Enum.reverse()
        |> Enum.map(fn test -> Jason.encode!(generate_testcases(test)) end)

      # Create a JSON Stream, where each line is 1 test.
      # This makes it easier to combine results
      result = suites |> Enum.join("\n")

      # save the report in an json file
      file_name = ExunitSummarizer.Utils.get_report_file_path()

      :ok = File.write!(file_name, result, [:write])

      if Application.get_env(:exunit_json_formatter, :print_report_filename?, false) do
        IO.puts(:stderr, "Wrote ExUnit report to: #{file_name}")
      end
    else
      IO.puts(:stderr, "Skipping the writing of ExUnit report.")
    end
  end

  def generate_testcases(test = %ExUnit.Test{}) do
    base =
      test.tags
      |> Map.take([:file, :line, :describe, :describe_line, :test_type])
      |> Map.merge(%{
        app: Mix.Project.config()[:app],
        classname: Atom.to_string(test.case),
        name: Atom.to_string(test.name),
        # Time is stored in microseconds, normalize to seconds.
        time: test.time / 1_000_000,
        success: false,
        skipped: false,
        failed: false
      })

    case test do
      %ExUnit.Test{state: nil} ->
        base |> Map.merge(%{success: true})

      %ExUnit.Test{state: {:skipped, message}} ->
        base |> Map.merge(%{skipped: true, message: message})

      %ExUnit.Test{state: {:excluded, message}} ->
        base |> Map.merge(%{skipped: true, message: message})

      %ExUnit.Test{state: {:failed, failures}} ->
        body =
          test
          |> ExUnit.Formatter.format_test_failure(failures, 0, :infinity, fn _, msg -> msg end)

        base |> Map.merge(%{failed: true, message: message(failures), body: body})

      %ExUnit.Test{state: {:invalid, %name{} = module}} ->
        base
        |> Map.merge(%{
          failed: true,
          message: "Invalid module #{name}",
          body: "#{inspect(module)}"
        })
    end
  end

  defp message([msg | _]), do: message(msg)
  defp message({_, %ExUnit.AssertionError{message: reason}, _}), do: reason
  defp message({:error, reason, _}), do: "error: #{Exception.message(reason)}"
  defp message({type, reason, _}) when is_atom(type), do: "#{type}: #{inspect(reason)}"
  defp message({type, reason, _}), do: "#{inspect(type)}: #{inspect(reason)}"
end
