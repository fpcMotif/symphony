defmodule SymphonyElixir.E2E.FixtureOrchestrator do
  @moduledoc false

  use GenServer

  alias SymphonyElixir.StatusDashboard

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  @impl true
  def init(:ok) do
    {:ok, %{snapshot: initial_snapshot(), refresh_count: 0}}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state.snapshot, state}
  end

  @impl true
  def handle_call(:request_refresh, _from, state) do
    updated_snapshot = refreshed_snapshot(state.refresh_count + 1)
    StatusDashboard.notify_update()

    response = %{
      queued: true,
      coalesced: false,
      requested_at: DateTime.utc_now(),
      operations: ["poll", "reconcile"]
    }

    {:reply, response, %{state | snapshot: updated_snapshot, refresh_count: state.refresh_count + 1}}
  end

  @spec initial_snapshot() :: map()
  def initial_snapshot do
    %{
      running: [
        %{
          issue_id: "issue-dashboard-running",
          identifier: "MT-RUN",
          state: "In Progress",
          session_id: "thread-dashboard-1",
          turn_count: 7,
          codex_app_server_pid: nil,
          last_codex_message: "rendered",
          last_codex_timestamp: DateTime.utc_now(),
          last_codex_event: :notification,
          codex_input_tokens: 4,
          codex_output_tokens: 8,
          codex_total_tokens: 12,
          started_at: DateTime.utc_now()
        }
      ],
      retrying: [
        %{
          issue_id: "issue-dashboard-retry",
          identifier: "MT-RETRY",
          attempt: 2,
          due_in_ms: 5_000,
          error: "boom"
        }
      ],
      codex_totals: %{input_tokens: 4, output_tokens: 8, total_tokens: 12, seconds_running: 42.5},
      rate_limits: %{"primary" => %{"remaining" => 11}}
    }
  end

  @spec refreshed_snapshot(pos_integer()) :: map()
  def refreshed_snapshot(turn_count) do
    %{
      initial_snapshot()
      | running: [
          %{
            issue_id: "issue-dashboard-running",
            identifier: "MT-RUN",
            state: "In Progress",
            session_id: "thread-dashboard-1",
            turn_count: turn_count,
            codex_app_server_pid: nil,
            last_codex_message: %{
              event: :notification,
              message: %{
                payload: %{
                  "method" => "codex/event/agent_message_content_delta",
                  "params" => %{"msg" => %{"content" => "refreshed update #{turn_count}"}}
                }
              }
            },
            last_codex_timestamp: DateTime.utc_now(),
            last_codex_event: :notification,
            codex_input_tokens: 10,
            codex_output_tokens: 12,
            codex_total_tokens: 22,
            started_at: DateTime.utc_now()
          }
        ],
        codex_totals: %{input_tokens: 10, output_tokens: 12, total_tokens: 22, seconds_running: 64.0}
    }
  end
end

port = String.to_integer(System.get_env("E2E_PORT", "4101"))
orchestrator_name = Module.concat(SymphonyElixir.E2E, FixtureOrchestratorServer)

endpoint_config =
  :symphony_elixir
  |> Application.get_env(SymphonyElixirWeb.Endpoint, [])
  |> Keyword.merge(
    server: true,
    http: [ip: {127, 0, 0, 1}, port: port],
    orchestrator: orchestrator_name,
    snapshot_timeout_ms: 500
  )

Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)

{:ok, _pid} = SymphonyElixir.E2E.FixtureOrchestrator.start_link(name: orchestrator_name)
{:ok, _pid} = SymphonyElixirWeb.Endpoint.start_link()

IO.puts("E2E fixture endpoint listening on http://127.0.0.1:#{port}")
Process.sleep(:infinity)
