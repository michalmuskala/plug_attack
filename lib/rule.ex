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

    count   = do_throttle(storage, key, now, period)
    rem     = limit - count
    data    = [period: period, expires_at: expires_at(now, period),
               limit: limit, remaining: max(rem, 0)]
    {if(rem >= 0, do: :allow, else: :block), {:throttle, data}}
  end

  defp expires_at(now, period) do
    (div(now, period) + 1) * period
  end

  defp do_throttle(storage, key, now, period) do
    slot = div(now, period)
    storage_key = {key, slot}
    storage.update_counter(PlugAttack, storage_key, 1, {storage_key, 0})
  end
end
