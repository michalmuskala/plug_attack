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

  @doc """
  Implementation for the PlugAttack.Storage.increment/4 callback.
  """
  def increment(name, key, inc, expires_at) do
    :ets.update_counter(name, key, inc, {key, 0, expires_at})
  end

  @doc """
  Implementation for the PlugAttack.Storage.write_sliding_counter/3 callback.
  """
  def write_sliding_counter(name, key, now, expires_at) do
    true = :ets.insert(name, {{key, now}, 0, expires_at})
    :ok
  end

  @doc """
  Implementation for the PlugAttack.Storage.read_sliding_counter/3 callback.
  """
  def read_sliding_counter(name, key, now) do
    ms = [
      {
        {{:"$1", :_}, :_, :"$2"},
        [{:"=:=", {:const, key}, :"$1"}],
        [{:>, :"$2", {:const, now}}]
      }
    ]

    :ets.select_count(name, ms)
  end

  @doc """
  Implementation for the PlugAttack.Storage.write/4 callback.
  """
  def write(name, key, value, expires_at) do
    true = :ets.insert(name, {key, value, expires_at})
    :ok
  end

  @doc """
  Implementation for the PlugAttack.Storage.read/3 callback.
  """
  def read(name, key, now) do
    case :ets.lookup(name, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        {:ok, value}

      _ ->
        :error
    end
  end

  @doc """
  Forcefully clean the storage.
  """
  def clean(name) do
    :ets.delete_all_objects(name)
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
    opts = [:named_table, :set, :public, write_concurrency: true, read_concurrency: true]
    ^name = :ets.new(name, opts)
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
    ms = [{{:_, :_, :"$1"}, [], [{:<, :"$1", {:const, now}}]}]
    :ets.select_delete(name, ms)
  end

  defp schedule(period) do
    Process.send_after(self(), :clean, period)
  end
end
