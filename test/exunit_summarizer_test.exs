defmodule TestWithSummaryTest do
  use ExUnit.Case

  test "one that passes" do
    assert 1 == 1
  end

  test "one that fails" do
    assert 1 == 2
  end

  @tag :skip
  test "one that skipped" do
    assert 1 == 2
  end

  describe "a describe block" do
    test "one that passes" do
      assert 1 != 2
    end

    test "one that fails" do
      assert 1 == 2
    end
  end
end
