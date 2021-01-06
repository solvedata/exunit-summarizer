# Using put_env so these only get set when our test suite is running, not others.

# Remove timestamps so that the log output doesn't change between runs.
# This is only important for the external testing done in `test.sh`; but doesn't hurt here either
Application.put_env(:logger, :console, [format: "[$level] $message\n"], persistent: true)

# Turn on coloured output to make things prettier(and check that ansi codes are generated correctly).
Application.put_env(:elixir, :ansi_enabled, true, persistent: true)

ExUnit.start(capture_log: true, formatters: [ExunitSummarizer, ExUnit.CLIFormatter])
