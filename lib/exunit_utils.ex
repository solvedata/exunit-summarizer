defmodule ExunitSummarizer.ExUnitUtils do
  # Adapted from https://github.com/elixir-lang/elixir/blob/285a6a6f8479fb14100ab8be2786f7ec88e5b9ab/lib/ex_unit/lib/ex_unit/cli_formatter.ex#L344-L407

  @default_colors [
    diff_delete: :red,
    diff_delete_whitespace: IO.ANSI.color_background(2, 0, 0),
    diff_insert: :green,
    diff_insert_whitespace: IO.ANSI.color_background(0, 2, 0)
  ]

  def color_config() do
    @default_colors
    |> Keyword.merge(Application.get_env(:exunit_json_formatter, :colors, []))
    |> Keyword.put_new(:enabled, default_color_enabled())
  end

  def default_color_enabled() do
    System.get_env("MIX_TEST_REPORT_COLOR", "") != "" || IO.ANSI.enabled?()
  end

  # Color styles
  def colorize(escape, string, %{colors: colors}) do
    if colors[:enabled] do
      [escape, string, :reset]
      |> IO.ANSI.format_fragment(true)
      |> IO.iodata_to_binary()
    else
      string
    end
  end

  def colorize_doc(escape, doc, %{colors: colors}) do
    if colors[:enabled] do
      Inspect.Algebra.color(doc, escape, %Inspect.Opts{syntax_colors: colors})
    else
      doc
    end
  end

  def success(msg, config) do
    colorize(:green, msg, config)
  end

  def invalid(msg, config) do
    colorize(:yellow, msg, config)
  end

  def skipped(msg, config) do
    colorize(:yellow, msg, config)
  end

  def failure(msg, config) do
    colorize(:red, msg, config)
  end

  def formatter(:diff_enabled?, _, %{colors: colors}), do: colors[:enabled]

  def formatter(:error_info, msg, config), do: colorize(:red, msg, config)

  def formatter(:extra_info, msg, config), do: colorize(:cyan, msg, config)

  def formatter(:location_info, msg, config), do: colorize([:bright, :black], msg, config)

  def formatter(:diff_delete, doc, config), do: colorize_doc(:diff_delete, doc, config)

  def formatter(:diff_delete_whitespace, doc, config),
    do: colorize_doc(:diff_delete_whitespace, doc, config)

  def formatter(:diff_insert, doc, config), do: colorize_doc(:diff_insert, doc, config)

  def formatter(:diff_insert_whitespace, doc, config),
    do: colorize_doc(:diff_insert_whitespace, doc, config)

  def formatter(:blame_diff, msg, %{colors: colors} = config) do
    if colors[:enabled] do
      colorize(:red, msg, config)
    else
      "-" <> msg <> "-"
    end
  end

  def formatter(_, msg, _config), do: msg
end
