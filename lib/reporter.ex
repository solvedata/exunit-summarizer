defmodule ExunitSummarizer.Reporter do
  alias ExunitSummarizer.Utils

  def base_indent(), do: 2

  def get_all_tests() do
    ExunitSummarizer.ReportFiles.get_all_report_file_paths()
    |> Enum.map(&File.read!/1)
    |> Enum.flat_map(&String.split(&1, "\n"))
    |> Enum.filter(fn line -> line != "" end)
    |> Enum.map(fn line -> line |> Jason.decode!() end)
  end

  def test_report_summary_line(total, passed, skipped, failed) do
    test_count_parts = []

    test_count_parts =
      if failed do
        ["#{failed} failed" | test_count_parts]
      else
        test_count_parts
      end

    test_count_parts =
      if skipped do
        ["#{skipped} skipped" | test_count_parts]
      else
        test_count_parts
      end

    test_count_parts = ["#{passed} passed" | test_count_parts]

    "#{total} tests: #{test_count_parts |> Enum.join(", ")}"
  end

  @spec get_all_tests_by_app(any) :: {:error, String.t()} | {:ok, String.t()}
  def get_all_tests_by_app(options \\ []) do
    all_tests = get_all_tests()
    any_failed_tests? = all_tests |> Enum.any?(fn test -> test["failed"] end)

    output =
      all_tests
      |> Enum.group_by(fn test -> test["app"] end)
      |> Enum.sort()
      |> Enum.flat_map(fn {app, tests} ->
        skipped_tests = tests |> Enum.filter(fn test -> test["skipped"] end)
        failed_tests = tests |> Enum.filter(fn test -> test["failed"] end)
        passed_tests = tests |> Enum.filter(fn test -> test["success"] end)

        report_first_line =
          "\n#{app}: " <>
            test_report_summary_line(
              tests |> length(),
              passed_tests |> length(),
              skipped_tests |> length(),
              failed_tests |> length()
            )

        failed_test_report_lines =
          failed_tests
          |> generate_tests_lines(show_body: true)

        skipped_test_report_lines =
          skipped_tests
          |> generate_tests_lines()

        slow_test_time = options |> Keyword.get(:slow_test_minimum_time, 0.5)
        slow_test_report_count = options |> Keyword.get(:slow_test_report_count, 5)

        slow_test_report_lines =
          passed_tests
          |> Enum.filter(fn test -> test["time"] >= slow_test_time end)
          |> Enum.sort_by(fn test -> test["time"] end, :desc)
          |> Enum.take(slow_test_report_count)
          |> generate_tests_lines(show_time: true)

        report_content =
          cond do
            failed_test_report_lines != [] ->
              ["Failed tests:" | Utils.indent(failed_test_report_lines, base_indent())]

            any_failed_tests? ->
              # Some tests failed, prevent outputting any extra
              #  information that could muddy the build log
              []

            true ->
              report_lines =
                if skipped_test_report_lines != [] do
                  ["Skipped tests:" | Utils.indent(skipped_test_report_lines, base_indent())]
                else
                  []
                end

              if report_lines |> length() < 20 and slow_test_report_lines != [] do
                report_lines ++
                  ["Slow running tests:" | Utils.indent(slow_test_report_lines, base_indent())]
              else
                report_lines
              end
          end

        [report_first_line | Utils.indent(report_content, base_indent())]
      end)
      |> Enum.join("\n")

    if any_failed_tests? do
      {:error, output}
    else
      {:ok, output}
    end
  end

  def generate_tests_lines(tests, options \\ []) do
    tests
    |> Enum.group_by(fn test -> test["classname"] end)
    |> Enum.flat_map(fn {class, tests} ->
      [
        "#{class}"
        | tests |> Enum.flat_map(&generate_test_lines(&1, options)) |> Utils.indent(base_indent())
      ]
    end)
  end

  @spec generate_test_lines(%{optional(String.t()) => any()}, keyword()) :: list(String.t())
  def generate_test_lines(test, options \\ []) do
    test_name = test["name"]

    test_time =
      if options |> Keyword.get(:show_time) do
        "  (#{test["time"] |> Float.round(2) |> Float.to_string()}s)"
      else
        ""
      end

    test_body =
      if options |> Keyword.get(:show_body) && test["body"] do
        body = test["body"] |> String.trim() |> Utils.normalise_line_list()
        logs = test["logs"] || ""
        first_line = body |> List.first()

        if first_line && first_line |> String.starts_with?("0) ") do
          # First 2 lines are the test name and test file, skip them.
          body
          |> Enum.drop(2)
          |> Utils.strip_common_indent()
        else
          # Not sure about the contents, include it all.
          body
          |> Utils.strip_common_indent()
        end ++
          if logs |> String.trim() != "" do
            log_lines =
              logs
              |> Utils.remove_consecutive_newlines_preserving_ansi_codes()
              |> Utils.indent(base_indent())

            ["logs:" | log_lines]
          else
            []
          end
      else
        []
      end
      |> Utils.indent(base_indent())

    test_file = test["file"] |> Path.relative_to_cwd()
    test_line = test["line"]

    [
      "#{test_name}#{test_time}",
      "- #{test_file}:#{test_line}"
    ] ++ test_body
  end

  def generate_report() do
    get_all_tests_by_app()
  end
end
