defmodule ExunitSummarizer.Utils do
  def get_report_folder() do
    Path.join(Mix.Project.build_path(), "test_reports")
  end

  def get_report_file_suffix() do
    "-tests.json"
  end

  def get_report_file_path do
    reports_folder = get_report_folder()

    report_file =
      Path.join(reports_folder, "#{Mix.Project.config()[:app]}#{get_report_file_suffix()}")

    if not File.dir?(reports_folder) do
      File.mkdir!(reports_folder)
    end

    report_file
  end

  def get_all_report_file_paths() do
    folder = get_report_folder()

    folder
    |> File.ls!()
    |> Enum.filter(fn filename -> filename |> String.ends_with?(get_report_file_suffix()) end)
    |> Enum.sort()
    |> Enum.map(&Path.join(folder, &1))
  end

  def clean_all_report_files() do
    get_all_report_file_paths() |> Enum.map(&File.rm!/1)
  end

  def get_all_tests() do
    get_all_report_file_paths()
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

  def get_all_tests_by_app(options \\ []) do
    all_tests = get_all_tests()
    any_failed_tests? = all_tests |> Enum.any?(fn test -> test["failed"] end)

    output =
      all_tests
      |> Enum.group_by(fn test -> test["app"] end)
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
          |> generate_tests_lines()

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

        cond do
          failed_test_report_lines != [] ->
            [report_first_line, "Failed tests:" | failed_test_report_lines]

          any_failed_tests? ->
            # Some tests failed, prevent outputting any extra
            #  information that could muddy the build log
            [report_first_line]

          true ->
            report_lines =
              if skipped_test_report_lines != [] do
                [report_first_line, "Skipped tests:" | skipped_test_report_lines]
              else
                [report_first_line]
              end

            if report_lines |> length() < 20 and slow_test_report_lines != [] do
              report_lines ++ ["Slow running tests" | slow_test_report_lines]
            else
              report_lines
            end
        end
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
      [" #{class}" | tests |> Enum.flat_map(&generate_test_lines(&1, options))]
    end)
  end

  def generate_test_lines(test, options \\ []) do
    test_name = test["name"]

    test_time =
      if options |> Keyword.get(:show_time) do
        "  (#{test["time"] |> Float.round(2) |> Float.to_string()}s)"
      else
        ""
      end

    test_file = test["file"] |> Path.relative_to_cwd()
    test_line = test["line"]

    [
      "  #{test_name}#{test_time}  --  #{test_file}:#{test_line}"
    ]
  end

  def generate_report() do
    get_all_tests_by_app()
  end
end
