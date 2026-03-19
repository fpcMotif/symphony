defmodule SymphonyElixirWeb.PresenterTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.StatusDashboard
  alias SymphonyElixirWeb.Presenter

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

  test "state_payload/2 returns exact map shape with running and retrying entries" do
    orchestrator_name = Module.concat(__MODULE__, :StateOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot_fixture())

    payload = Presenter.state_payload(orchestrator_name, 50)

    running_message = running_message_fixture()

    assert payload == %{
             generated_at: payload.generated_at,
             counts: %{running: 1, retrying: 1},
             workflow_graph: %{
               nodes: [
                 %{
                   id: "poll",
                   label: "Poll",
                   status: "live",
                   metric: payload.workflow_graph.nodes |> Enum.at(0) |> Map.fetch!(:metric),
                   detail: "Last refresh #{payload.generated_at}"
                 },
                 %{
                   id: "dispatch",
                   label: "Dispatch",
                   status: "active",
                   metric: "10 slots",
                   detail: "1 running / 1 queued"
                 },
                 %{
                   id: "run",
                   label: "Run",
                   status: "active",
                   metric: "1 active",
                   detail: payload.workflow_graph.nodes |> Enum.at(2) |> Map.fetch!(:detail)
                 },
                 %{
                   id: "retry",
                   label: "Retry",
                   status: "warning",
                   metric: "1 queued",
                   detail: payload.workflow_graph.nodes |> Enum.at(3) |> Map.fetch!(:detail)
                 }
               ],
               edges: [
                 %{from: "poll", to: "dispatch"},
                 %{from: "dispatch", to: "run"},
                 %{from: "run", to: "retry"},
                 %{from: "retry", to: "dispatch"}
               ]
             },
             running: [
               %{
                 issue_id: "issue-running",
                 issue_identifier: "MT-123",
                 state: "In Progress",
                 worker_host: nil,
                 workspace_path: nil,
                 session_id: "thread-running",
                 turn_count: 3,
                 last_event: :session_started,
                 last_message: StatusDashboard.humanize_codex_message(running_message),
                 started_at: "2026-01-15T10:00:05Z",
                 last_event_at: "2026-01-15T10:00:40Z",
                 tokens: %{input_tokens: 11, output_tokens: 22, total_tokens: 33}
               }
             ],
             retrying: [
               %{
                 issue_id: "issue-retry",
                 issue_identifier: "MT-999",
                 attempt: 2,
                 due_at: payload.retrying |> hd() |> Map.fetch!(:due_at),
                 error: "retry failed",
                 worker_host: nil,
                 workspace_path: nil
               }
             ],
             codex_totals: %{input_tokens: 11, output_tokens: 22, total_tokens: 33, seconds_running: 45.5},
             rate_limits: %{primary: %{remaining: 99}}
           }

    assert_iso8601_second_precision(payload.generated_at)
    assert_iso8601_second_precision(payload.retrying |> hd() |> Map.fetch!(:due_at))
    assert payload.workflow_graph.nodes |> Enum.at(0) |> Map.fetch!(:metric) == "30.0s interval"
    assert payload.workflow_graph.nodes |> Enum.at(2) |> Map.fetch!(:detail) =~ "Oldest run"
    assert payload.workflow_graph.nodes |> Enum.at(3) |> Map.fetch!(:detail) =~ "Next due"
  end

  test "state_payload/2 returns timeout error payload" do
    orchestrator_name = Module.concat(__MODULE__, :TimeoutOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: :timeout)

    payload = Presenter.state_payload(orchestrator_name, 50)

    assert payload == %{
             generated_at: payload.generated_at,
             error: %{code: "snapshot_timeout", message: "Snapshot timed out"}
           }

    assert_iso8601_second_precision(payload.generated_at)
  end

  test "state_payload/2 returns unavailable error payload" do
    orchestrator_name = Module.concat(__MODULE__, :UnavailableOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: :unavailable)

    payload = Presenter.state_payload(orchestrator_name, 50)

    assert payload == %{
             generated_at: payload.generated_at,
             error: %{code: "snapshot_unavailable", message: "Snapshot unavailable"}
           }

    assert_iso8601_second_precision(payload.generated_at)
  end

  test "issue_payload/3 returns running-only issue" do
    orchestrator_name = Module.concat(__MODULE__, :RunningIssueOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot_fixture())

    assert {:ok, payload} = Presenter.issue_payload("MT-123", orchestrator_name, 50)

    running_message = running_message_fixture()

    assert payload == %{
             issue_identifier: "MT-123",
             issue_id: "issue-running",
             status: "running",
             workspace: %{path: workspace_path_for("MT-123"), host: nil},
             attempts: %{restart_count: 0, current_retry_attempt: 0},
             running: %{
               worker_host: nil,
               workspace_path: nil,
               session_id: "thread-running",
               turn_count: 3,
               state: "In Progress",
               started_at: "2026-01-15T10:00:05Z",
               last_event: :session_started,
               last_message: StatusDashboard.humanize_codex_message(running_message),
               last_event_at: "2026-01-15T10:00:40Z",
               tokens: %{input_tokens: 11, output_tokens: 22, total_tokens: 33}
             },
             retry: nil,
             logs: %{codex_session_logs: []},
             recent_events: [
               %{
                 at: "2026-01-15T10:00:40Z",
                 event: :session_started,
                 message: StatusDashboard.humanize_codex_message(running_message)
               }
             ],
             last_error: nil,
             tracked: %{}
           }
  end

  test "issue_payload/3 returns retry-only issue" do
    orchestrator_name = Module.concat(__MODULE__, :RetryIssueOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot_fixture())

    assert {:ok, payload} = Presenter.issue_payload("MT-999", orchestrator_name, 50)

    assert payload == %{
             issue_identifier: "MT-999",
             issue_id: "issue-retry",
             status: "retrying",
             workspace: %{path: workspace_path_for("MT-999"), host: nil},
             attempts: %{restart_count: 1, current_retry_attempt: 2},
             running: nil,
             retry: %{
               attempt: 2,
               due_at: payload.retry.due_at,
               error: "retry failed",
               worker_host: nil,
               workspace_path: nil
             },
             logs: %{codex_session_logs: []},
             recent_events: [],
             last_error: "retry failed",
             tracked: %{}
           }

    assert_iso8601_second_precision(payload.retry.due_at)
  end

  test "issue_payload/3 returns error for missing issue" do
    orchestrator_name = Module.concat(__MODULE__, :MissingIssueOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot_fixture())

    assert {:error, :issue_not_found} = Presenter.issue_payload("MT-MISSING", orchestrator_name, 50)
  end

  test "issue_payload/3 returns timeout error when snapshot times out" do
    orchestrator_name = Module.concat(__MODULE__, :IssueTimeoutOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: :timeout)

    assert {:error, :snapshot_timeout} = Presenter.issue_payload("MT-123", orchestrator_name, 50)
  end

  test "issue_payload/3 returns unavailable error when snapshot is unavailable" do
    orchestrator_name = Module.concat(__MODULE__, :IssueUnavailableOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: :unavailable)

    assert {:error, :snapshot_unavailable} = Presenter.issue_payload("MT-123", orchestrator_name, 50)
  end

  test "refresh_payload/1 returns exact response and second-precision requested_at" do
    orchestrator_name = Module.concat(__MODULE__, :RefreshOrchestrator)

    {:ok, _pid} =
      StaticOrchestrator.start_link(
        name: orchestrator_name,
        snapshot: snapshot_fixture(),
        refresh: %{queued: true, coalesced: false, operations: ["poll"], requested_at: ~U[2026-01-15 10:00:59.912345Z]}
      )

    assert {:ok, payload} = Presenter.refresh_payload(orchestrator_name)

    assert payload == %{
             queued: true,
             coalesced: false,
             operations: ["poll"],
             requested_at: "2026-01-15T10:00:59.912345Z"
           }
  end

  defp snapshot_fixture do
    %{
      running: [
        %{
          issue_id: "issue-running",
          identifier: "MT-123",
          state: "In Progress",
          session_id: "thread-running",
          turn_count: 3,
          last_codex_event: :session_started,
          last_codex_message: running_message_fixture(),
          started_at: ~U[2026-01-15 10:00:05.987654Z],
          last_codex_timestamp: ~U[2026-01-15 10:00:40.123456Z],
          codex_input_tokens: 11,
          codex_output_tokens: 22,
          codex_total_tokens: 33
        }
      ],
      retrying: [
        %{
          issue_id: "issue-retry",
          identifier: "MT-999",
          attempt: 2,
          due_in_ms: 65_000,
          error: "retry failed"
        }
      ],
      codex_totals: %{input_tokens: 11, output_tokens: 22, total_tokens: 33, seconds_running: 45.5},
      rate_limits: %{primary: %{remaining: 99}}
    }
  end

  defp running_message_fixture do
    %{event: :session_started, message: %{"payload" => %{"session_id" => "thread-running"}}}
  end

  defp workspace_path_for(issue_identifier) do
    assert {:ok, workspace_path} = Workspace.path_for_issue(issue_identifier)
    workspace_path
  end

  defp assert_iso8601_second_precision(value) do
    assert {:ok, datetime, 0} = DateTime.from_iso8601(value)
    assert datetime.microsecond == {0, 0}
  end
end
