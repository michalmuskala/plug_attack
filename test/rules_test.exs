defmodule PlugAttack.RuleTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, _} = PlugAttack.Storage.Ets.start_link(__MODULE__)
    :ok
  end

  test "fail2ban" do
    assert {:allow, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(1)
    assert {:allow, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(150)

    assert {:allow, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(1)
    assert {:allow, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(1)
    assert {:allow, {:fail2ban, :counting, :key}} = fail2ban()
    :timer.sleep(100)
    assert {:block, {:fail2ban, :banned, :key, 99}} = fail2ban()
    :timer.sleep(200)
    assert {:allow, {:fail2ban, :counting, :key}} = fail2ban()
  end

  defp fail2ban() do
    PlugAttack.Rule.fail2ban(:key,
      storage: {PlugAttack.Storage.Ets, __MODULE__},
      period: 100,
      limit: 3,
      ban_for: 200
    )
  end

  test "throttle" do
    assert {:allow, {:throttle, data}} = throttle()

    expires = (div(System.system_time(:millisecond), 100) + 1) * 100
    assert data[:period] == 100
    assert data[:limit] == 5
    assert data[:remaining] == 4
    assert data[:expires_at] == expires

    assert {:allow, _} = throttle()
    assert {:allow, _} = throttle()
    assert {:allow, _} = throttle()
    assert {:allow, _} = throttle()

    assert {:block, {:throttle, data}} = throttle()
    assert data[:period] == 100
    assert data[:limit] == 5
    assert data[:remaining] == 0
    assert data[:expires_at] == expires

    :timer.sleep(90)
    assert {:allow, {:throttle, data}} = throttle()
    assert data[:period] == 100
    assert data[:limit] == 5
    assert data[:remaining] == 4
    assert data[:expires_at] == expires + 100
  end

  defp throttle() do
    PlugAttack.Rule.throttle(:key,
      storage: {PlugAttack.Storage.Ets, __MODULE__},
      limit: 5,
      period: 100
    )
  end
end
