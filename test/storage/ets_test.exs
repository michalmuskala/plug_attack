defmodule PlugAttack.Storage.EtsTest do
  use ExUnit.Case, async: true

  alias PlugAttack.Storage.Ets

  setup do
    {:ok, pid} = Ets.start_link(__MODULE__, clean_period: 100)
    {:ok, pid: pid}
  end

  test "increment/4" do
    assert 1 == Ets.increment(__MODULE__, :foo, 1, expires_in(10))
    assert 2 == Ets.increment(__MODULE__, :foo, 1, expires_in(10))
    assert 4 == Ets.increment(__MODULE__, :foo, 2, expires_in(10))
  end

  test "sliding counter" do
    assert 0 = Ets.read_sliding_counter(__MODULE__, :foo, now())
    Ets.write_sliding_counter(__MODULE__, :foo, now(), expires_in(20))
    Ets.write_sliding_counter(__MODULE__, :foo, now() + 1, expires_in(20))
    assert 2 = Ets.read_sliding_counter(__MODULE__, :foo, now())
    :timer.sleep(30)
    assert 0 = Ets.read_sliding_counter(__MODULE__, :foo, now())
  end

  test "read/write" do
    assert :error = Ets.read(__MODULE__, :foo, now())
    Ets.write(__MODULE__, :foo, true, expires_in(20))
    assert {:ok, true} == Ets.read(__MODULE__, :foo, now())
    :timer.sleep(30)
    assert :error = Ets.read(__MODULE__, :foo, now())
  end

  test "cleans periodically" do
    assert 1 = Ets.increment(__MODULE__, :foo, 1, expires_in(10))
    :timer.sleep(150)
    assert 1 = Ets.increment(__MODULE__, :foo, 1, expires_in(10))
  end

  defp expires_in(ms), do: System.system_time(:millisecond) + ms

  defp now(), do: System.system_time(:millisecond)
end
