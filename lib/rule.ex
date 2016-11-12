defmodule PlugAttack.Rule do
  def allow(value) do
    if value do
      {:allow, value}
    else
      nil
    end
  end

  def block(value) do
    if value do
      {:block, value}
    else
      nil
    end
  end

  def throttle(key, opts) do
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
    full_key = {key, div(now, period)}
    mod.increment(opts, full_key, 1, expires_at)
  end
end
