defmodule ExunitSummarizerTest do
  use ExUnit.Case
  doctest ExunitSummarizer

  test "greets the world" do
    assert ExunitSummarizer.hello() == :world
  end
end
