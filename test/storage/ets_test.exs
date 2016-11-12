# defmodule PlugAttack.Storage.EtsTest do
#   use ExUnit.Case, async: true

#   alias PlugAttack.Storage.Ets

#   setup do
#     {:ok, pid} = Ets.start_link(name: __MODULE__, clean_period: 100)
#     {:ok, pid: pid}
#   end

#   test "increments correctly" do
#     assert 1 == Ets.increment(__MODULE__, :foo, 1, 10)
#     assert 2 == Ets.increment(__MODULE__, :foo, 1, 10)
#     assert 4 == Ets.increment(__MODULE__, :foo, 2, 10)
#   end

#   test "cleans periodically" do
#     assert 1 = Ets.increment(__MODULE__, :foo, 1, 10)
#     :timer.sleep(100)
#     assert 1 = Ets.increment(__MODULE__, :foo, 1, 10)
#   end
# end
