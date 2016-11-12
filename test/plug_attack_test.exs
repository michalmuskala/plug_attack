defmodule PlugAttackTest do
  use ExUnit.Case, async: true
  use Plug.Test

  doctest PlugAttack

  defmodule TestPlug do
    use PlugAttack

    rule "rule",  do: Process.get(:rule)
    rule "allow", do: if Process.get(:allow), do: {:allow, []}
    rule "block", do: if Process.get(:block), do: {:block, []}

    rule "throttle", conn do
      PlugAttack.Rule.throttle(conn.remote_ip,
        storage: {PlugAttack.Storage.Ets, PlugAttackTest}, limit: 5, period: 100)
    end

    def block_action(conn, data, opts) do
      send(self(), {:block, data})
      super(conn, data, opts)
    end

    def allow_action(conn, data, opts) do
      send(self(), {:allow, data})
      super(conn, data, opts)
    end
  end

  setup do
    {:ok, pid} = PlugAttack.Storage.Ets.start_link(name: __MODULE__)
    {:ok, conn: conn(:get, "/"), pid: pid}
  end

  test "creates a plug" do
    assert function_exported?(TestPlug, :init, 1)
    assert function_exported?(TestPlug, :call, 2)
  end

  test "uses the rule definition with allow", %{conn: conn} do
    Process.put(:rule, {:allow, []})
    conn = TestPlug.call(conn, TestPlug.init([]))
    refute conn.halted
  end

  test "uses the rule definition with block", %{conn: conn} do
    Process.put(:rule, {:block, []})
    conn = TestPlug.call(conn, TestPlug.init([]))
    assert conn.halted
    assert {403, _, "Forbidden!\n"} = sent_resp(conn)
  end

  test "runs the rules in the correct order", %{conn: conn} do
    Process.put(:rule, nil)
    Process.put(:allow, true)
    Process.put(:block, true)
    conn = TestPlug.call(conn, TestPlug.init([]))
    refute conn.halted
  end

  test "throttle", %{conn: conn} do
    refute call(TestPlug, conn).halted

    expires = (div(System.system_time(:milliseconds), 100) + 1) * 100
    assert_receive {:allow, {:throttle, data}}
    assert data[:period]     == 100
    assert data[:limit]      == 5
    assert data[:remaining]  == 4
    assert data[:expires_at] == expires

    refute call(TestPlug, conn).halted
    refute call(TestPlug, conn).halted
    refute call(TestPlug, conn).halted
    refute call(TestPlug, conn).halted
    flush()

    assert call(TestPlug, conn).halted
    assert_receive {:block, {:throttle, data}}
    assert data[:period]     == 100
    assert data[:limit]      == 5
    assert data[:remaining]  == 0
    assert data[:expires_at] == expires

    :timer.sleep(100)
    refute call(TestPlug, conn).halted
    assert_receive {:allow, {:throttle, data}}
    assert data[:period]     == 100
    assert data[:limit]      == 5
    assert data[:remaining]  == 4
    assert data[:expires_at] == expires + 100
  end

  defp call(plug, conn, opts \\ []), do: plug.call(conn, plug.init(opts))

  defp flush() do
    receive do
      _ -> flush
    after
      0 -> :ok
    end
  end
end
