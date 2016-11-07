defmodule PlugAttackTest do
  use ExUnit.Case
  use Plug.Test

  doctest PlugAttack

  defmodule TestPlug do
    use PlugAttack

    rule "rule",  do: Process.get(:rule)
    rule "allow", do: if Process.get(:allow), do: {:allow, []}
    rule "block", do: if Process.get(:block), do: {:block, []}

    rule "throttle", conn,
      do: PlugAttack.Rule.throttle(conn.remote_ip, storage: :ets, limit: 5, period: 100)
  end

  setup do
    :ets.new(PlugAttack, [:named_table, :ordered_set, write_concurrency: true])
    {:ok, conn: conn(:get, "/")}
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

  test "throttle works", %{conn: conn} do
    refute TestPlug.call(conn, TestPlug.init([])).halted
    refute TestPlug.call(conn, TestPlug.init([])).halted
    refute TestPlug.call(conn, TestPlug.init([])).halted
    refute TestPlug.call(conn, TestPlug.init([])).halted
    refute TestPlug.call(conn, TestPlug.init([])).halted

    assert TestPlug.call(conn, TestPlug.init([])).halted
    :timer.sleep(100)
    refute TestPlug.call(conn, TestPlug.init([])).halted
  end
end
