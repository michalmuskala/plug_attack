defmodule PlugAttack.Storage.Ets do
  @moduledoc """
  Storage solution for PlugAttack using a local ets table.

  ## Usage

  You need to start the process in your supervision tree, for example:

      children = [
        # ...
        worker(PlugAttack.Storage.Ets, [MyApp.PlugAttackStorage])
      ]

  This will later allow you to pass the `:storage` option to various rules
  as `storage: {PlugAttack.Ets, MyApp.PlugAttackStorage}`

  """

  use GenServer
  @behaviour PlugAttack.Storage
  @compile {:parse_transform, :ms_transform}

  @doc """
  Implementation for the PlugAttack.Storage.increment/4 callback
  """
  def increment(name, key, inc, expires_at) do
    :ets.update_counter(name, key, inc, {key, 0, expires_at})
  end

  @doc """
  Starts the storage table and cleaner process.

  The process is registered under `name` and a public, named ets table
  with that name is created as well.

  ## Options

    * `:clean_period` - how often the ets table should be cleaned of stale
      data. The key scheme guarantees stale data won't be used for making
      decisions. This is only about limiting memory consumption
      (default: 5000 ms).

  """
  def start_link(name, opts \\ []) do
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
