defmodule ExunitSummarizer.ReportFiles do
  def get_report_folder() do
    Path.join(Mix.Project.build_path(), "test_reports")
  end

  def get_report_file_suffix() do
    "-tests.json"
  end

  def get_report_file_path() do
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

    case folder |> File.ls() do
      {:ok, filenames} ->
        filenames
        |> Enum.filter(fn filename -> filename |> String.ends_with?(get_report_file_suffix()) end)
        |> Enum.sort()
        |> Enum.map(&Path.join(folder, &1))

      # File doesn't exist. All other errors should raise.
      {:error, :enoent} ->
        []
    end
  end

  def clean_all_report_files() do
    get_all_report_file_paths() |> Enum.map(&File.rm!/1)
  end
end
