defmodule ExunitSummarizer.UtilsTest do
  use ExUnit.Case
  alias ExunitSummarizer.Utils

  describe "indent/2" do
    test "works with lists" do
      assert ["  test ", "   other "] == Utils.indent(["test ", " other "], "  ")
    end

    test "works with strings" do
      assert ["  test ", "   other "] == Utils.indent("test \n other ", "  ")
    end

    test "works with indent number and lists" do
      assert ["\u00A0test ", "\u00A0 other "] == Utils.indent(["test ", " other "], 1)
    end

    test "works with indent number and strings" do
      assert ["\u00A0test ", "\u00A0 other "] == Utils.indent("test \n other ", 1)
    end
  end

  describe "normalise_line_list/1" do
    test "works with lists" do
      assert ["test ", " other "] == Utils.normalise_line_list(["test ", " other "])
    end

    test "works with lists with newlines" do
      assert ["test ", " other ", "line"] == Utils.normalise_line_list(["test ", " other \nline"])
    end

    test "works with strings" do
      assert ["test ", " other "] == Utils.normalise_line_list(["test ", " other "])
    end
  end

  describe "remove_consecutive_newlines_preserving_ansi_codes/1" do
    test "does nothing with lists without codes" do
      assert ["test", " other "] ==
               Utils.remove_consecutive_newlines_preserving_ansi_codes(["test", " other "])
    end

    test "does nothing with an empty list" do
      assert [] ==
               Utils.remove_consecutive_newlines_preserving_ansi_codes([])
    end

    test "works with lists" do
      assert [
               "\u001B[33m14:01:19.789 [warn]  This should output.\u001B[0m\u001B[31m",
               "14:01:19.789 [error] This should show an error.\u001B[0m"
             ] ==
               Utils.remove_consecutive_newlines_preserving_ansi_codes([
                 "\u001B[33m",
                 "14:01:19.789 [warn]  This should output.",
                 "\u001B[0m\u001B[31m",
                 "14:01:19.789 [error] This should show an error.",
                 "\u001B[0m"
               ])
    end

    test "works with multiple lines between codes" do
      assert [
               "\u001B[33m14:01:19.789 [warn]  This should output.",
               "new line! \u001B[0m\u001B[31m",
               "14:01:19.789 [error] This should show an error.\u001B[0m"
             ] ==
               Utils.remove_consecutive_newlines_preserving_ansi_codes([
                 "\u001B[33m",
                 "14:01:19.789 [warn]  This should output.",
                 "new line! ",
                 "\u001B[0m\u001B[31m",
                 "14:01:19.789 [error] This should show an error.",
                 "\u001B[0m"
               ])
    end

    test "works with codes split across multiple lines" do
      assert [
               "\u001B[33m14:01:19.789 [warn]  This should output.",
               "new line! \u001B[0m\u001B[31m",
               "14:01:19.789 [error] This should show an error.\u001B[0m"
             ] ==
               Utils.remove_consecutive_newlines_preserving_ansi_codes([
                 "\u001B[33m",
                 "14:01:19.789 [warn]  This should output.",
                 "new line! ",
                 "\u001B[0m",
                 "\u001B[31m",
                 "14:01:19.789 [error] This should show an error.",
                 "\u001B[0m"
               ])
    end

    test "preserves truely blank lines" do
      assert [
               "\u001B[33m14:01:19.789 [warn]  This should output.",
               "",
               "new line! ",
               "\u001B[0m\u001B[31m",
               "14:01:19.789 [error] This should show an error.\u001B[0m"
             ] ==
               Utils.remove_consecutive_newlines_preserving_ansi_codes([
                 "\u001B[33m",
                 "14:01:19.789 [warn]  This should output.",
                 "",
                 "new line! ",
                 "",
                 "\u001B[0m",
                 "\u001B[31m",
                 "14:01:19.789 [error] This should show an error.",
                 "\u001B[0m"
               ])
    end
  end
end
