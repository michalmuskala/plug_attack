defmodule PlugAttack.RuleTest do
  use ExUnit.Case, async: true
  use Plug.Test

  doctest PlugAttack.Rule

  @storage {PlugAttack.Storage.Ets, __MODULE__}

  setup do
    {:ok, _} = PlugAttack.Storage.Ets.start_link(__MODULE__)
    :ok
  end

  test "fail2ban" do
    assert {:block, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(1)
    assert {:block, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(150)

    assert {:block, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(1)
    assert {:block, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(1)
    assert {:block, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(100)
    assert {:block, {:fail2ban, :banned, :key}} = fail2ban()
    :timer.sleep(200)
    assert {:block, {:fail2ban, :counting, :key}} = fail2ban()
  end

  defp fail2ban() do
    PlugAttack.Rule.fail2ban(:key,
      storage: @storage, period: 100, limit: 3, ban_for: 200)
  end

  test "throttle" do
    assert {:allow, {:throttle, data}} = throttle()

    expires = (div(System.system_time(:milliseconds), 100) + 1) * 100
    assert data[:period]     == 100
    assert data[:limit]      == 5
    assert data[:remaining]  == 4
    assert data[:expires_at] == expires

    assert {:allow, _} = throttle()
    assert {:allow, _} = throttle()
    assert {:allow, _} = throttle()
    assert {:allow, _} = throttle()

    assert {:block, {:throttle, data}} = throttle()
    assert data[:period]     == 100
    assert data[:limit]      == 5
    assert data[:remaining]  == 0
    assert data[:expires_at] == expires

    :timer.sleep(100)
    assert {:allow, {:throttle, data}} = throttle()
    assert data[:period]     == 100
    assert data[:limit]      == 5
    assert data[:remaining]  == 4
    assert data[:expires_at] == expires + 100
  end

  defp throttle() do
    PlugAttack.Rule.throttle(:key,
      storage: @storage, limit: 5, period: 100)
  end

  describe "conditional throttle" do
    setup do
      [conn: conn(:get, "/")]
    end

    test "conditional throttle with unconditional request", %{conn: conn} do
      assert {:allow, {:throttle, _}} = conditional_throttle(conn)
      assert {:allow, {:throttle, _}} = conditional_throttle(conn)
      assert {:block, {:throttle, _}} = conditional_throttle(conn)
    end

    test "conditional throttle with If-None-Match request", %{conn: conn} do
      conditional =
        conn
        |> put_private(:plug_attack, {__MODULE__, self()})
        |> put_req_header("if-none-match", "x")

      assert %Plug.Conn{} = req1 = conditional_throttle(conditional)
      assert %Plug.Conn{} = req2 = conditional_throttle(conditional)
      assert %Plug.Conn{} = req3 = conditional_throttle(conditional)

      refute_received {:allow_action, _, _}

      send_resp(req1, 304, "")
      assert_received {:allow_action, _, _}
      send_resp(req2, 200, "")
      assert_received {:allow_action, _, _}
      assert {:allow, _} = conditional_throttle(conn)
      assert {:block, _} = conditional_throttle(conn)

      # This is the race condition described in the docs
      send_resp(req3, 200, "")
      assert_received {:allow_action, _, _}
    end
  end

  defp conditional_throttle(conn) do
    PlugAttack.Rule.conditional_throttle(conn, :key,
      storage: @storage, limit: 2, period: 100)
  end

  # Simulating PlugAttack for conditional throttle test
  def allow_action(conn, data, pid) do
    send(pid, {:allow_action, conn, data})
    conn
  end
end
