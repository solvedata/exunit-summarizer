defmodule TestWithSummaryTest do
  use ExUnit.Case
  doctest Mix.Tasks.TestWithSummary

  test "one that passes" do
    assert 1 == 1
  end

  test "one that fails" do
    assert 1 == 2
  end
end
