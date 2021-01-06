# ExunitSummarizer

Simply runs `mix test` in an umbrella app and prints out a nicely formatted summary of how many
tests have failed, along with the failure messages. Inspiration for this is Jest's output from
Javascript testing.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `exunit_summarizer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:exunit_summarizer, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/exunit_summarizer](https://hexdocs.pm/exunit_summarizer).

## Testing

This repo comes with both Elixir tests(for the various utilities) and a bash script for testing both the report JSON files, the generated textual report and the clean commands.

To run the tests ensure you have both `elixir`, [`jq`](https://stedolan.github.io/jq/), and `diff` on your path. Then run `./test.sh` in the root of the repository. It will run tests and generate reports.

## Making changes

Most of the report functionality is located in `lib/reporter.ex`. Once a change is made to the output the `./test.sh` script will fail until the 'known-good' sample files in `test/files` are updated.

The best way to do this is to run the tests, look at the last line of output like the one below:

```console
$ ./test.sh
...snip...
[FAIL] Files differ. See output above: ./_build/test_report_output.txt == ./test/files/failure-test_report_output.txt
$
```

If the failure is that two files differ, simply copy the left file into the right. So for the example above:

```console
$ ./test.sh
...snip...
[FAIL] Files differ. See output above: ./_build/test_report_output.txt == ./test/files/failure-test_report_output.txt
$ cp  ./_build/test_report_output.txt ./test/files/failure-test_report_output.txt
$ ./test.sh
...snip...
[PASS] All tests pass.
$
```

There are other failure modes:

- `[FAIL] Report JSON files differ(in a way that matters). See output above: file_a == file_b"`
  This indicates that the report JSON differs(after rounding all `time`s to the nearest second). This could be because the format has changed(in which case run `cp file_a file_b`), or that the tests are running _really_ slow.

- `[FAIL] Files differ. See output above: file_a == file_b"`
  This indicates that the textual report differs. This could be because the format has changed(in which case run `cp file_a file_b`), or that the tests are running _really_ slow.

- `[FAIL] File doesn't exist: file_a"`
  This indicates that a file that the app should have created was not created. Check that the `ExunitSummarizer`(in `lib/exunit_summarizer.ex`) is being executed in the tests by looking for a `Wrote ExUnit report to` line. Otherwise check that the `ExunitSummarizer` is actually writing out the file to the correct location.

- `[FAIL] File exists: file_a"`
  This indicates that a file that the app should have removed was not removed. Check that the `test.report.clean` command(in `lib/mix_test_report_clean.ex`, and it's implementation in `lib/report_files.ex`) is working correctly. It should remove files in `_build/test/test_reports` that end with the test suffix of `-tests.json`.

- `[FAIL] Command returned 42, was expecting success: mix do thing`
  This indicates that a command that should have returned successfully did not. Check the output above this line to investigate why.

  For `mix test` and `mix test.report`, these will fail if any tests fail. Check for test that failed that shouldn't have.
  For `mix test.report.clean`, this will fail if it is unable to delete a test report.

- `[FAIL] Command returned 0, was expecting failure: mix not do thing`
  This indicates that a command that should have failed did not. Check the output above this line to investigate why.

  For `mix test` and `mix test.report`, these will succeed if no tests fail. Check that the test failures written into `test/exunit_summarizer_test.exs` are still present.
