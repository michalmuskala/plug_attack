# PlugAttack

A plug building toolkit for blocking and throttling abusive requests.

This is inspired by the Kickstarter's Rack::Attack middleware for Ruby.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `plug_attack` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:plug_attack, "~> 0.3.0"}]
    end
    ```

  2. Ensure `plug_attack` is started before your application:

    ```elixir
    def application do
      [applications: [:plug_attack]]
    end
    ```

## Basic usage

We first need to construct a plug that will list various rules we want to apply:

```elixir
defmodule MyApp.PlugAttack do
  use PlugAttack

  rule "allow local", conn do
    allow conn.remote_ip == {127, 0, 0, 1}
  end
end
```

The `MyApp.PlugAttack` module is now a regular plug that can be used, for
example, in a phoenix endpoint.

*WARNING*: if you're behind a proxy, like nginx or heroku's router, you need to
make sure you have a plug that respects the `X-Forwarded-For` headers, for
example: [remote_ip](https://hex.pm/packages/remote_ip).

## Throttling

Before we implement throttling in our attack plug, we need to add a storage to
our supervision tree. This can be achieved by adding following to the
supervision tree:

```elixir
children = [
  # other children
  worker(PlugAttack.Storage.Ets, [MyApp.PlugAttack.Storage, [clean_period: 60_000]])
]
```

We've configured the table to be cleaned of stale data every minute. The
usage patterns of the table by the throttling rules means no stale data will be
ever accessed. This is only a measure used to control the memory usage.

Now we can add a rule to our plug allowing 10 requests every minute from a single
ip address:

```elixir
rule "throttle by ip", conn do
  throttle conn.remote_ip,
    period: 60_000, limit: 10,
    storage: {PlugAttack.Storage.Ets, MyApp.PlugAttack.Storage}
end
```

## Rate limiting headers

We can customize the actions taken by `PlugAttack` on blocked or allowed
requests, by adding rate limiting headers for well behaved clients.

To do this, we can define two functions in our plug - `allow_action/3` and
`block_action/3`. Those are similar to regular plugs - accepting a connection
as the first argument and opts as the last one. The middle argument represents
the blocking or allowing data returned by the rule. The throttling rule returns
data in the form of `{:throttle, data}`, where `data` is a keyword with various
useful data we can use to construct rate limiting headers.

```elixir
def allow_action(conn, {:throttle, data}, opts) do
  conn
  |> add_throttling_headers(data)
  |> allow_action(true, opts)
end

def allow_action(conn, _data, _opts) do
  conn
end

def block_action(conn, {:throttle, data}, _opts) do
  conn
  |> add_throttling_headers(data)
  |> block_action(false, opts)
end

def block_action(conn, _data, _opts) do
  conn
  |> send_resp(:forbidden, "Forbidden\n")
  |> halt # It's important to halt connection once we send a response early
end

defp add_throttling_headers(conn, data) do
  # The expires_at value is a unix time in milliseconds, we want to return one
  # in seconds
  reset = div(data[:expires_at], 1_000)
  conn
  |> put_resp_header("x-ratelimit-limit", to_string(data[:limit]))
  |> put_resp_header("x-ratelimit-remaining", to_string(data[:remaining]))
  |> put_resp_header("x-ratelimit-reset", to_string(reset))
end
```

## License

Copyright 2015 Michał Muskała

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
