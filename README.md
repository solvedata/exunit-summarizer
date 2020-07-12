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

