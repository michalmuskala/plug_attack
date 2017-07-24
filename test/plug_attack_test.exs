defmodule PlugAttackTest do
  use ExUnit.Case, async: true
  use Plug.Test

  doctest PlugAttack

  defmodule TestPlug do
    use PlugAttack

    rule "rule",  do: Process.get(:rule)
    rule "allow", do: if Process.get(:allow), do: {:allow, []}
    rule "block", do: if Process.get(:block), do: {:block, []}

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
    {:ok, conn: conn(:get, "/")}
  end

  test "creates a plug" do
    assert function_exported?(TestPlug, :init, 1)
    assert function_exported?(TestPlug, :call, 2)
  end

  test "stores plug & opts in private", %{conn: conn} do
    ref = make_ref()
    conn = TestPlug.call(conn, TestPlug.init(ref))
    assert {TestPlug, ref} == conn.private.plug_attack
  end

  test "uses the rule definition with allow", %{conn: conn} do
    Process.put(:rule, {:allow, []})
    conn = TestPlug.call(conn, TestPlug.init([]))
    refute conn.halted
    assert_received {:allow, []}
  end

  test "allows returning updated conn from a rule", %{conn: conn} do
    updated = Plug.Conn.assign(conn, :test, make_ref())
    Process.put(:rule, updated)
    conn = TestPlug.call(conn, TestPlug.init([]))
    assert conn == updated
  end

  test "uses the rule definition with block", %{conn: conn} do
    Process.put(:rule, {:block, []})
    conn = TestPlug.call(conn, TestPlug.init([]))
    assert conn.halted
    assert {403, _, "Forbidden\n"} = sent_resp(conn)
    assert_received {:block, []}
  end

  test "runs the rules in the correct order", %{conn: conn} do
    Process.put(:rule, nil)
    Process.put(:allow, true)
    Process.put(:block, true)
    conn = TestPlug.call(conn, TestPlug.init([]))
    refute conn.halted
    assert_received {:allow, []}
  end
end
