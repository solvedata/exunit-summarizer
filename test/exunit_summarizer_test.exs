defmodule TestWithSummaryTest do
  use ExUnit.Case
  require Logger

  @should_fail System.get_env("MAKE_TESTS_FAIL", "")
  @should_slow System.get_env("MAKE_TESTS_SLOW", "")

  test "one that passes" do
    Logger.warning("This should not output")
    assert 1 == 1
  end

  test "one that fails when MAKE_TESTS_FAIL != \"\"" do
    Logger.warning("This should output.")
    Logger.error("This should show an error.")
    assert @should_fail == ""
  end

  @tag :skip
  test "one that skipped" do
    assert 1 == 2
  end

  test "slow test" do
    if @should_slow != "" do
      :timer.sleep(2000)
    end
  end

  describe "a describe block" do
    test "one that passes" do
      assert 1 != 2
    end

    test "one that fails when MAKE_TESTS_FAIL != \"\"" do
      assert @should_fail == ""
    end
  end
end
