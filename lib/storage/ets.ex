defmodule PlugAttack.Storage.Ets do
  use GenServer
  @behaviour PlugAttack.Storage
  @compile {:parse_transform, :ms_transform}

  def increment(name, key, inc, expires_at) do
    :ets.update_counter(name, key, inc, {key, 0, expires_at})
  end

  def start_link(opts) do
    name         = Keyword.fetch!(opts, :name)
    clean_period = Keyword.get(opts, :clean_period, 5_000)
    GenServer.start_link(__MODULE__, {name, clean_period}, opts)
  end

  @doc false
  def init({name, clean_period}) do
    ^name = :ets.new(name, [:named_table, :set, :public, write_concurrency: true])
    schedule(clean_period)
    {:ok, %{clean_period: clean_period, name: name}}
  end

  @doc false
  def handle_info(:clean, state) do
    do_clean(state.name)
    schedule(state.clean_period)
    {:noreply, state}
  end

  defp do_clean(name) do
    now = System.system_time(:milliseconds)
    ms = :ets.fun2ms(fn {_, _, expires_at} -> expires_at < now end)
    :ets.select_delete(name, ms)
  end

  defp schedule(period) do
    Process.send_after(self(), :clean, period)
  end
end
