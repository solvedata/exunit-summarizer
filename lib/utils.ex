defmodule ExunitSummarizer.Utils do
  @spec indent(String.t() | list(String.t()), binary | non_neg_integer) :: list(String.t())
  def indent(lines, spaces) when is_integer(spaces) do
    # Use non-breaking spaces to trick Drone into looking half decent.
    indent(lines, String.duplicate("\u00A0", spaces))
  end

  def indent(lines, prefix) when is_binary(prefix) do
    lines |> normalise_line_list() |> Enum.map(fn line -> prefix <> line end)
  end

  @spec normalise_line_list(String.t() | list(String.t())) :: list(String.t())
  def normalise_line_list(lines) when is_list(lines) do
    lines |> Enum.flat_map(fn line -> String.split(line, "\n") end)
  end

  def normalise_line_list(lines) when is_binary(lines) do
    lines |> String.split("\n")
  end

  def strip_common_indent(lines) do
    lines = lines |> normalise_line_list()

    min_indent =
      lines
      |> Enum.flat_map(fn line ->
        deindented_chars = line |> String.trim_leading() |> String.length()
        # If the line is empty, ignore it. Otherwise return the number of characters removed .
        if deindented_chars == 0 do
          []
        else
          [(line |> String.length()) - deindented_chars]
        end
      end)
      |> Enum.min(fn -> 0 end)

    lines
    |> Enum.map(fn line ->
      {_indent, deindented_line} = line |> String.split_at(min_indent)
      deindented_line
    end)
  end

  def remove_consecutive_newlines_preserving_ansi_codes(lines) do
    line_contains_only_ansi_codes_regex = ~r|^(?:\x1b(?:\[[0-9;]*[A-HJKSTfimnsu]))+$|
    lines = lines |> normalise_line_list()

    if lines |> Enum.empty?() do
      []
    else
      {{_is_ansi, prev_line}, lines} =
        lines
        |> Enum.reduce({{true, ""}, []}, fn line, {{is_prev_line_ansi_only, prev_line}, lines} ->
          # Does the line contain at least one ANSI code, and only ANSI codes.
          # An empty string will result in `line_contains_only_ansi_codes = false`.
          line_contains_only_ansi_codes =
            line |> String.match?(line_contains_only_ansi_codes_regex)

          if line_contains_only_ansi_codes do
            {{is_prev_line_ansi_only, prev_line <> line}, lines}
          else
            # This line is not blank
            # If the previous line was only ansi codes, append this line to the previous line
            # Otherwise add the previous line to the `lines` list and this line will become the previous line for the next iteration.
            if is_prev_line_ansi_only do
              {{false, prev_line <> line}, lines}
            else
              {{false, line}, [prev_line | lines]}
            end
          end
        end)

      [prev_line | lines] |> Enum.reverse()
    end
  end
end
