defmodule SymphonyElixir.DashboardLiveTest do
  use SymphonyElixir.TestSupport

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias SymphonyElixir.StatusDashboard

  @endpoint SymphonyElixirWeb.Endpoint

  defmodule StaticOrchestrator do
    use GenServer

    def start_link(opts) do
      name = Keyword.fetch!(opts, :name)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def init(opts), do: {:ok, opts}

    def handle_call(:snapshot, _from, state) do
      {:reply, Keyword.fetch!(state, :snapshot), state}
    end

    def handle_call(:request_refresh, _from, state) do
      {:reply, Keyword.get(state, :refresh, :unavailable), state}
    end
  end

  test "mounts / and renders dashboard markers" do
    orchestrator_name = Module.concat(__MODULE__, :DashboardOrchestrator)

    {:ok, _pid} =
      StaticOrchestrator.start_link(
        name: orchestrator_name,
        snapshot: static_snapshot(),
        refresh: %{queued: true, coalesced: false, requested_at: DateTime.utc_now(), operations: ["poll"]}
      )

    start_test_endpoint(orchestrator: orchestrator_name, snapshot_timeout_ms: 50)

    {:ok, _view, html} = live(build_conn(), "/")

    assert html =~ "Operations Dashboard"
    assert html =~ "Running"
    assert html =~ "Retrying"
    assert html =~ "Total tokens"
    assert html =~ "Runtime"
    assert html =~ "Rate limits"
    assert html =~ "Running sessions"
    assert html =~ "Retry queue"
    assert html =~ "MT-HTTP"
  end

  test "refreshes payload after :observability_updated pubsub broadcast" do
    orchestrator_name = Module.concat(__MODULE__, :PubSubOrchestrator)
    initial_snapshot = static_snapshot()

    {:ok, orchestrator_pid} =
      StaticOrchestrator.start_link(
        name: orchestrator_name,
        snapshot: initial_snapshot,
        refresh: %{queued: true, coalesced: true, requested_at: DateTime.utc_now(), operations: ["poll"]}
      )

    start_test_endpoint(orchestrator: orchestrator_name, snapshot_timeout_ms: 50)

    {:ok, view, html} = live(build_conn(), "/")
    assert html =~ "MT-HTTP"
    refute html =~ "MT-NEW"

    updated_snapshot =
      put_in(initial_snapshot.running, [
        %{
          issue_id: "issue-new",
          identifier: "MT-NEW",
          state: "In Progress",
          session_id: "thread-new",
          turn_count: 9,
          codex_app_server_pid: nil,
          last_codex_message: "new render",
          last_codex_timestamp: nil,
          last_codex_event: :notification,
          codex_input_tokens: 9,
          codex_output_tokens: 13,
          codex_total_tokens: 22,
          started_at: DateTime.utc_now()
        }
      ])

    :sys.replace_state(orchestrator_pid, fn state ->
      Keyword.put(state, :snapshot, updated_snapshot)
    end)

    StatusDashboard.notify_update()

    assert_eventually(fn ->
      refreshed_html = render(view)
      refreshed_html =~ "MT-NEW" and refreshed_html =~ "new render"
    end)
  end

  test "renders unavailable snapshot error card" do
    start_test_endpoint(
      orchestrator: Module.concat(__MODULE__, :MissingOrchestrator),
      snapshot_timeout_ms: 5
    )

    {:ok, _view, html} = live(build_conn(), "/")

    assert html =~ "Snapshot unavailable"
    assert html =~ "snapshot_unavailable"
  end

  defp start_test_endpoint(overrides) do
    endpoint_config =
      :symphony_elixir
      |> Application.get_env(SymphonyElixirWeb.Endpoint, [])
      |> Keyword.merge(server: false, secret_key_base: String.duplicate("s", 64))
      |> Keyword.merge(overrides)

    Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)
    start_supervised!({SymphonyElixirWeb.Endpoint, []})
  end

  defp static_snapshot do
    %{
      running: [
        %{
          issue_id: "issue-http",
          identifier: "MT-HTTP",
          state: "In Progress",
          session_id: "thread-http",
          turn_count: 7,
          codex_app_server_pid: nil,
          last_codex_message: "rendered",
          last_codex_timestamp: nil,
          last_codex_event: :notification,
          codex_input_tokens: 4,
          codex_output_tokens: 8,
          codex_total_tokens: 12,
          started_at: DateTime.utc_now()
        }
      ],
      retrying: [
        %{
          issue_id: "issue-retry",
          identifier: "MT-RETRY",
          attempt: 2,
          due_in_ms: 2_000,
          error: "boom"
        }
      ],
      codex_totals: %{input_tokens: 4, output_tokens: 8, total_tokens: 12, seconds_running: 42.5},
      rate_limits: %{"primary" => %{"remaining" => 11}}
    }
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      true
    else
      Process.sleep(25)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("condition not met in time")
end
