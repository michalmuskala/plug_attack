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
  @spec throttle(term, Keyword.t) :: PlugAttack.rule
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

  @doc """
  Implements an algorithm inspired by fail2ban.

  This intends to catch misbehaving clients early and for longer amounts of
  time. The `key` differentiates different clients, you can use, for example,
  `conn.remote_ip` for per IP tracking. If the `key` is falsey the action is
  skipped and next rules are evaluated.

  Be careful not to use the same `key` for different rules that use the same
  storage.

  Passes `{:fail2ban, key}`, as the data to `block_action` calls when an
  abusive request is detected. Each misbehaving client is blocked after each
  call and tracked for `:period` time. If more than `:limit` abusive requests
  are detected within the `:period`, the client is banned for `:ban_for`.

  ## Options

    * `:storage` - required, a tuple of `PlugAttack.Storage` implementation
      and storage options.
    * `:period` - required, how long to store abusive requests for counting
      towards `:limit` exhaustion.
    * `:limit` - required, max abusive requests allowed before the ban.
    * `:ban_for` - required, length of the ban in milliseconds.

  """
  @spec fail2ban(term, Keyword.t) :: PlugAttack.rule
  def fail2ban(key, opts) do
    if key do
      do_fail2ban(key, opts)
    else
      nil
    end
  end

  defp do_fail2ban(key, opts) do
    storage = Keyword.fetch!(opts, :storage)
    limit   = Keyword.fetch!(opts, :limit)
    period  = Keyword.fetch!(opts, :period)
    ban_for = Keyword.fetch!(opts, :ban_for)
    now     = System.system_time(:milliseconds)

    if banned?(key, storage, now) do
      {:block, {:fail2ban, :banned, key}}
    else
      track_fail2ban(key, storage, limit, period, ban_for, now)
    end
  end

  defp banned?(key, {mod, opts}, now) do
    mod.read(opts, {:fail2ban_banned, key}, now) == {:ok, true}
  end

  defp track_fail2ban(key, {mod, opts}, limit, period, ban_for, now) do
    mod.write_sliding_counter(opts, {:fail2ban, key}, now, now + period)
    if mod.read_sliding_counter(opts, {:fail2ban, key}, now) >= limit do
      mod.write(opts, {:fail2ban_banned, key}, true, now + ban_for)
    end
    {:block, {:fail2ban, :counting, key}}
  end
end
