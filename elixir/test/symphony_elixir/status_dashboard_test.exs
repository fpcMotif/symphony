defmodule SymphonyElixir.StatusDashboardTest do
  use SymphonyElixir.TestSupport

  test "init applies keyword overrides" do
    assert {:ok, state} =
             StatusDashboard.init(
               refresh_ms: 2_500,
               enabled: false,
               render_interval_ms: 42,
               render_fun: fn _ -> :ok end
             )

    assert state.refresh_ms == 2_500
    assert state.enabled == false
    assert state.render_interval_ms == 42
    assert state.refresh_ms_override == 2_500
    assert state.enabled_override == false
    assert state.render_interval_ms_override == 42
  end

  test "notify_update returns :ok when dashboard process is not running" do
    assert :ok = StatusDashboard.notify_update(:nonexistent_dashboard)
  end

  test "rolling_tps and throttled_tps handle edge cases" do
    now_ms = System.monotonic_time(:millisecond)

    assert StatusDashboard.rolling_tps([], now_ms, 100) == 0.0
    assert StatusDashboard.rolling_tps([{now_ms, 100}], now_ms, 100) == 0.0

    assert {second, 12.5} =
             StatusDashboard.throttled_tps(div(now_ms, 1000), 12.5, now_ms, [{now_ms - 1_000, 100}], 200)

    assert second == div(now_ms, 1000)
  end

  test "format helpers expose stable output for invalid and fallback inputs" do
    assert StatusDashboard.dashboard_url_for_test("  ", 4_000, 4_001) == "http://127.0.0.1:4001/"
    assert StatusDashboard.dashboard_url_for_test("::1", nil, nil) == nil

    summary =
      StatusDashboard.format_running_summary_for_test(%{
        identifier: nil,
        state: nil,
        session_id: nil,
        codex_app_server_pid: nil,
        last_codex_event: nil,
        last_codex_message: nil,
        codex_total_tokens: nil,
        runtime_seconds: nil,
        turn_count: 0
      })

    assert summary =~ "unknown"
    assert summary =~ "no codex message yet"
  end
end
