defmodule ExunitSummarizer.Stats do
  defstruct failures: 0,
            skipped: 0,
            tests: 0,
            test_cases: [],
            failed_test_cases: []

  @type t :: %__MODULE__{
          failures: non_neg_integer,
          skipped: non_neg_integer,
          tests: non_neg_integer,
          test_cases: [ExUnit.Test.t()],
          failed_test_cases: [ExUnit.Test.t()]
        }
end
