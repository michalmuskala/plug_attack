defmodule PlugAttack.Rule do
  @moduledoc """
  Defines various rules that can be used inside the `PlugAttack.rule/2` macro.
  """

  @doc """
  The simplest rule that always allows the request to pass.

  If `value` is truthy the request is allowed, otherwise next rules are
  evaluated.
  """
  @spec allow(term) :: PlugAttack.rule
  def allow(value) do
    if value do
      {:allow, value}
    else
      nil
    end
  end

  @doc """
  The simplest rule that always blocks the request.

  If `value` is truthy the request is blocked, otherwise next rules are
  evaluated.
  """
  @spec block(term) :: PlugAttack.rule
  def block(value) do
    if value do
      {:block, value}
    else
      nil
    end
  end

  @doc """
  Implements a request throttling algorithm.

  The `key` differentiates different throttles, you can use, for example,
  `conn.remote_ip` for per IP throttling, or an email address for login attempts
  limitation. If the `key` is falsey the throttling is not performed and
  next rules are evaluated.

  Be careful not to use the same `key` for different rules that use the same
  storage.

  Passes `{:throttle, data}`, as the data to both allow and block tuples, where
  data is a keyword containing: `:period`, `:limit`, `:expires_at` - when the
  current limit will expire as unix time in milliseconds,
  and `:remaining` - the remaining limit. This can be useful for adding
  "X-RateLimit-*" headers.

  ## Options

    * `:storage` - required, a tuple of `PlugAttack.Storage` implementation
      and storage options.
    * `:limit` - required, how many requests in a period are allowed.
    * `:period` - required, how long, in ms, is the period.

  """
  @spec throttle(term, [opt]) :: PlugAttack.rule when
    opt: {:storage, {PlugAttack.Storage.t, PlugAttack.Storage.opts}} |
         {:limit, pos_integer} |
         {:period, pos_integer}
  def throttle(key, opts) do
    if key do
      do_throttle(key, opts)
    else
      nil
    end
  end

  defp do_throttle(key, opts) do
    storage = Keyword.fetch!(opts, :storage)
    limit   = Keyword.fetch!(opts, :limit)
    period  = Keyword.fetch!(opts, :period)
    now     = System.system_time(:milliseconds)

    expires_at = expires_at(now, period)
    count      = do_throttle(storage, key, now, period, expires_at)
    rem        = limit - count
    data       = [period: period, expires_at: expires_at,
                  limit: limit, remaining: max(rem, 0)]
    {if(rem >= 0, do: :allow, else: :block), {:throttle, data}}
  end

  defp expires_at(now, period), do: (div(now, period) + 1) * period

  defp do_throttle({mod, opts}, key, now, period, expires_at) do
    full_key = {:throttle, key, div(now, period)}
    mod.increment(opts, full_key, 1, expires_at)
  end
end
