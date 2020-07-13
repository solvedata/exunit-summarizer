defmodule Mix.Tasks.TestWithSummary do
  use Mix.Task

  @shortdoc "Runs exunit tests with a summary at the end"

  alias Mix.Compilers.Test, as: CT

  @compile {:no_warn_undefined, [ExUnit, ExUnit.Filters]}
  @shortdoc "Runs a project's tests"
  @recursive true
  @preferred_cli_env :test

  @switches [
    force: :boolean,
    color: :boolean,
    cover: :boolean,
    export_coverage: :string,
    trace: :boolean,
    max_cases: :integer,
    max_failures: :integer,
    include: :keep,
    exclude: :keep,
    seed: :integer,
    only: :keep,
    compile: :boolean,
    start: :boolean,
    timeout: :integer,
    raise: :boolean,
    deps_check: :boolean,
    archives_check: :boolean,
    elixir_version_check: :boolean,
    failed: :boolean,
    stale: :boolean,
    listen_on_stdin: :boolean,
    formatter: :keep,
    slowest: :integer,
    partitions: :integer,
    preload_modules: :boolean
  ]

  @cover [output: "cover", tool: Mix.Tasks.Test.Coverage]

  def run(args) do
    {opts, files} = OptionParser.parse!(args, strict: @switches)

    if not Mix.Task.recursing?() do
      do_run(opts, args, files)
    else
      {files_in_apps_path, files_not_in_apps_path} =
        Enum.split_with(files, &String.starts_with?(&1, "apps/"))

      app = Mix.Project.config()[:app]
      current_app_path = "apps/#{app}/"

      files_in_current_app_path =
        for file <- files_in_apps_path,
            String.starts_with?(file, current_app_path) or not relative_app_file_exists?(file),
            do: String.trim_leading(file, current_app_path)

      files = files_in_current_app_path ++ files_not_in_apps_path

      if files == [] and files_in_apps_path != [] do
        :ok
      else
        do_run([test_location_relative_path: "apps/#{app}"] ++ opts, args, files)
      end
    end
  end

  defp relative_app_file_exists?(file) do
    {file, _} = ExUnit.Filters.parse_path(file)
    File.exists?(Path.join("../..", file))
  end

  defp do_run(opts, args, files) do
    if opts[:listen_on_stdin] do
      System.at_exit(fn _ ->
        IO.gets(:stdio, "")
        Mix.shell().info("Restarting...")
        :init.restart()
        Process.sleep(:infinity)
      end)
    end

    unless System.get_env("MIX_ENV") || Mix.env() == :test do
      Mix.raise("""
      "mix test" is running in the \"#{Mix.env()}\" environment. If you are \
      running tests from within another command, you can either:
        1. set MIX_ENV explicitly:
            MIX_ENV=test mix test.another
        2. set the :preferred_cli_env for a command inside "def project" in your mix.exs:
            preferred_cli_env: ["test.another": :test]
      """)
    end

    # Load ExUnit before we compile anything
    Application.ensure_loaded(:ex_unit)

    Mix.Task.run("compile", args)
    project = Mix.Project.config()

    # Start cover after we load deps but before we start the app.
    cover =
      if opts[:cover] do
        compile_path = Mix.Project.compile_path(project)
        partition = opts[:partitions] && System.get_env("MIX_TEST_PARTITION")

        cover =
          @cover
          |> Keyword.put(:export, opts[:export_coverage] || partition)
          |> Keyword.merge(project[:test_coverage] || [])

        cover[:tool].start(compile_path, cover)
      end

    # Start the app and configure ExUnit with command line options
    # before requiring test_helper.exs so that the configuration is
    # available in test_helper.exs
    Mix.shell().print_app
    app_start_args = if opts[:slowest], do: ["--preload-modules" | args], else: args
    Mix.Task.run("app.start", app_start_args)

    # The test helper may change the Mix.shell(), so revert it whenever we raise and after suite
    shell = Mix.shell()

    # Configure ExUnit now and then again so the task options override test_helper.exs
    {ex_unit_opts, allowed_files} = process_ex_unit_opts(opts)
    ExUnit.configure(ex_unit_opts)

    test_paths = project[:test_paths] || default_test_paths()
    Enum.each(test_paths, &require_test_helper(shell, &1))
    ExUnit.configure(merge_helper_opts(ex_unit_opts))

    # Finally parse, require and load the files
    test_files = parse_files(files, shell, test_paths)
    test_pattern = project[:test_pattern] || "*_test.exs"
    warn_test_pattern = project[:warn_test_pattern] || "*_test.ex"

    matched_test_files =
      test_files
      |> Mix.Utils.extract_files(test_pattern)
      |> filter_to_allowed_files(allowed_files)
      |> filter_by_partition(shell, opts)

    display_warn_test_pattern(test_files, test_pattern, matched_test_files, warn_test_pattern)

    case CT.require_and_run(matched_test_files, test_paths, opts) do
      {:ok, %{excluded: excluded, failures: failures, total: total}} ->
        Mix.shell(shell)
        IO.inspect(excluded, label: "BANANA excl")
        IO.inspect(failures, label: "BANANA fails")
        IO.inspect(total, label: "BANANA total")
        cover && cover.()

        cond do
          failures > 0 and opts[:raise] ->
            raise_with_shell(shell, "\"mix test\" failed")

          failures > 0 ->
            System.at_exit(fn _ -> exit({:shutdown, 1}) end)

          excluded == total and Keyword.has_key?(opts, :only) ->
            message = "The --only option was given to \"mix test\" but no test was executed"
            raise_or_error_at_exit(shell, message, opts)

          true ->
            :ok
        end

      :noop ->
        cond do
          opts[:stale] ->
            Mix.shell().info("No stale tests")

          files == [] ->
            Mix.shell().info("There are no tests to run")

          true ->
            message = "Paths given to \"mix test\" did not match any directory/file: "
            raise_or_error_at_exit(shell, message <> Enum.join(files, ", "), opts)
        end

        :ok
    end

    IO.inspect("after?", label: "BANANA")
  end

  defp raise_with_shell(shell, message) do
    Mix.shell(shell)
    Mix.raise(message)
  end

  defp raise_or_error_at_exit(shell, message, opts) do
    cond do
      opts[:raise] ->
        raise_with_shell(shell, message)

      Mix.Task.recursing?() ->
        Mix.shell().info(message)

      true ->
        Mix.shell().error(message)
        System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp display_warn_test_pattern(test_files, test_pattern, matched_test_files, warn_test_pattern) do
    files = Mix.Utils.extract_files(test_files, warn_test_pattern) -- matched_test_files

    for file <- files do
      Mix.shell().info(
        "warning: #{file} does not match #{inspect(test_pattern)} and won't be loaded"
      )
    end
  end

  @option_keys [
    :trace,
    :max_cases,
    :max_failures,
    :include,
    :exclude,
    :seed,
    :timeout,
    :formatters,
    :colors,
    :slowest,
    :failures_manifest_file,
    :only_test_ids,
    :test_location_relative_path
  ]

  @doc false
  def process_ex_unit_opts(opts) do
    {opts, allowed_files} = manifest_opts(opts)

    opts =
      opts
      |> filter_opts(:include)
      |> filter_opts(:exclude)
      |> filter_opts(:only)
      |> formatter_opts()
      |> color_opts()
      |> Keyword.take(@option_keys)
      |> default_opts()

    {opts, allowed_files}
  end

  defp merge_helper_opts(opts) do
    # The only options that are additive from app env are the excludes
    merge_opts(opts, :exclude)
  end

  defp merge_opts(opts, key) do
    value = List.wrap(Application.get_env(:ex_unit, key, []))
    Keyword.update(opts, key, value, &Enum.uniq(&1 ++ value))
  end

  defp default_opts(opts) do
    # Set autorun to false because Mix
    # automatically runs the test suite for us.
    [autorun: false] ++ opts
  end

  defp parse_files([], _shell, test_paths) do
    test_paths
  end

  defp parse_files([single_file], _shell, _test_paths) do
    # Check if the single file path matches test/path/to_test.exs:123. If it does,
    # apply "--only line:123" and trim the trailing :123 part.
    {single_file, opts} = ExUnit.Filters.parse_path(single_file)
    ExUnit.configure(opts)
    [single_file]
  end

  defp parse_files(files, shell, _test_paths) do
    if Enum.any?(files, &match?({_, [_ | _]}, ExUnit.Filters.parse_path(&1))) do
      raise_with_shell(shell, "Line numbers can only be used when running a single test file")
    else
      files
    end
  end

  defp parse_filters(opts, key) do
    if Keyword.has_key?(opts, key) do
      ExUnit.Filters.parse(Keyword.get_values(opts, key))
    end
  end

  defp filter_opts(opts, :only) do
    if filters = parse_filters(opts, :only) do
      opts
      |> Keyword.update(:include, filters, &(filters ++ &1))
      |> Keyword.update(:exclude, [:test], &[:test | &1])
    else
      opts
    end
  end

  defp filter_opts(opts, key) do
    if filters = parse_filters(opts, key) do
      Keyword.put(opts, key, filters)
    else
      opts
    end
  end

  defp formatter_opts(opts) do
    if Keyword.has_key?(opts, :formatter) do
      formatters =
        opts
        |> Keyword.get_values(:formatter)
        |> Enum.map(&Module.concat([&1]))

      Keyword.put(opts, :formatters, formatters)
    else
      opts
    end
  end

  @manifest_file_name ".mix_test_failures"

  defp manifest_opts(opts) do
    manifest_file = Path.join(Mix.Project.manifest_path(), @manifest_file_name)
    opts = Keyword.put(opts, :failures_manifest_file, manifest_file)

    if opts[:failed] do
      if opts[:stale] do
        Mix.raise("Combining --failed and --stale is not supported.")
      end

      {allowed_files, failed_ids} = ExUnit.Filters.failure_info(manifest_file)
      {Keyword.put(opts, :only_test_ids, failed_ids), allowed_files}
    else
      {opts, nil}
    end
  end

  defp filter_to_allowed_files(matched_test_files, nil), do: matched_test_files

  defp filter_to_allowed_files(matched_test_files, %MapSet{} = allowed_files) do
    Enum.filter(matched_test_files, &MapSet.member?(allowed_files, Path.expand(&1)))
  end

  defp filter_by_partition(files, shell, opts) do
    if total = opts[:partitions] do
      partition = System.get_env("MIX_TEST_PARTITION")

      case partition && Integer.parse(partition) do
        {partition, ""} when partition in 1..total ->
          partition = partition - 1

          # We sort the files because Path.wildcard does not guarantee
          # ordering, so different OSes could return a different order,
          # meaning run across OSes on different partitions could run
          # duplicate files.
          for {file, index} <- Enum.with_index(Enum.sort(files)),
              rem(index, total) == partition,
              do: file

        _ ->
          raise_with_shell(
            shell,
            "The MIX_TEST_PARTITION environment variable must be set to an integer between " <>
              "1..#{total} when the --partitions option is set, got: #{inspect(partition)}"
          )
      end
    else
      files
    end
  end

  defp color_opts(opts) do
    case Keyword.fetch(opts, :color) do
      {:ok, enabled?} ->
        Keyword.put(opts, :colors, enabled: enabled?)

      :error ->
        opts
    end
  end

  defp require_test_helper(shell, dir) do
    file = Path.join(dir, "test_helper.exs")

    if File.exists?(file) do
      Code.require_file(file)
    else
      raise_with_shell(
        shell,
        "Cannot run tests because test helper file #{inspect(file)} does not exist"
      )
    end
  end

  defp default_test_paths do
    if File.dir?("test") do
      ["test"]
    else
      []
    end
  end
end
