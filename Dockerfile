ARG elixir_version=1.13.0
FROM elixir:${elixir_version}

SHELL [ "/bin/bash", "-exuo", "pipefail", "-c" ]

RUN apt-get update \
    && apt-get install --no-install-recommends -y jq=1.5+dfsg-2+b1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /src

WORKDIR /src/

COPY mix.exs mix.lock /src/

RUN mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get \
    && mix deps.compile --skip-umbrella-children --include-children

COPY . /src/

RUN ./test.sh
