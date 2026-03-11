defmodule SymphonyElixir.PresenterTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixirWeb.Presenter

  defmodule StaticOrchestrator do
    use GenServer

    def start_link(opts) do
      name = Keyword.fetch!(opts, :name)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def handle_call(:snapshot, _from, state) do
      {:reply, Keyword.fetch!(state, :snapshot), state}
    end

    @impl true
    def handle_call(:request_refresh, _from, state) do
      {:reply, Keyword.get(state, :refresh, :unavailable), state}
    end
  end

  describe "state_payload/2" do
    test "returns snapshot payload shape when orchestrator snapshot succeeds" do
      started_at = ~U[2025-01-02 03:04:05.987654Z]

      orchestrator =
        start_orchestrator(%{
          running: [
            %{
              issue_id: "issue-1",
              identifier: "ENG-1",
              state: :running,
              session_id: "session-1",
              turn_count: 3,
              last_codex_event: :notification,
              last_codex_message: %{method: "turn/completed"},
              started_at: started_at,
              last_codex_timestamp: started_at,
              codex_input_tokens: 10,
              codex_output_tokens: 5,
              codex_total_tokens: 15
            }
          ],
          retrying: [
            %{
              issue_id: "issue-2",
              identifier: "ENG-2",
              attempt: 2,
              due_in_ms: 60_000,
              error: %{message: "retry later"}
            }
          ],
          codex_totals: %{input_tokens: 11, output_tokens: 7, total_tokens: 18, seconds_running: 12},
          rate_limits: %{primary: %{remaining: 42}}
        })

      payload = Presenter.state_payload(orchestrator, 25)

      assert %{
               generated_at: generated_at,
               counts: %{running: 1, retrying: 1},
               running: [running],
               retrying: [retrying],
               codex_totals: %{input_tokens: 11, output_tokens: 7, total_tokens: 18, seconds_running: 12},
               rate_limits: %{primary: %{remaining: 42}}
             } = payload

      assert_iso8601!(generated_at)
      assert running.started_at == "2025-01-02T03:04:05Z"
      assert_iso8601!(retrying.due_at)
      refute String.contains?(retrying.due_at, ".")
    end

    test "returns snapshot_timeout error payload when snapshot times out" do
      orchestrator = start_orchestrator(:timeout)

      assert %{generated_at: generated_at, error: %{code: "snapshot_timeout"}} =
               Presenter.state_payload(orchestrator, 1)

      assert_iso8601!(generated_at)
    end

    test "returns snapshot_unavailable error payload when snapshot is unavailable" do
      orchestrator = start_orchestrator(:unavailable)

      assert %{generated_at: generated_at, error: %{code: "snapshot_unavailable"}} =
               Presenter.state_payload(orchestrator, 1)

      assert_iso8601!(generated_at)
    end
  end

  describe "issue_payload/3" do
    test "returns payload when running issue is present" do
      started_at = ~U[2025-01-02 03:04:05.987654Z]

      orchestrator =
        start_orchestrator(%{
          running: [
            %{
              issue_id: "issue-1",
              identifier: "ENG-1",
              state: :running,
              session_id: "session-1",
              turn_count: 1,
              started_at: started_at,
              last_codex_event: :notification,
              last_codex_message: %{method: "turn/completed"},
              last_codex_timestamp: started_at,
              codex_input_tokens: 1,
              codex_output_tokens: 2,
              codex_total_tokens: 3
            }
          ],
          retrying: [],
          codex_totals: %{},
          rate_limits: %{}
        })

      assert {:ok, %{status: "running", running: running, retry: nil, attempts: attempts}} =
               Presenter.issue_payload("ENG-1", orchestrator, 25)

      assert running.started_at == "2025-01-02T03:04:05Z"
      assert attempts.restart_count == 0
      assert attempts.current_retry_attempt == 0
    end

    test "returns payload when retry issue is present" do
      orchestrator =
        start_orchestrator(%{
          running: [],
          retrying: [
            %{
              issue_id: "issue-2",
              identifier: "ENG-2",
              attempt: 3,
              due_in_ms: 90_000,
              error: %{message: "retrying"}
            }
          ],
          codex_totals: %{},
          rate_limits: %{}
        })

      assert {:ok, %{status: "retrying", running: nil, retry: retry, attempts: %{restart_count: 2, current_retry_attempt: 3}}} =
               Presenter.issue_payload("ENG-2", orchestrator, 25)

      assert_iso8601!(retry.due_at)
      refute String.contains?(retry.due_at, ".")
    end

    test "returns running status when both running and retry entries are present" do
      started_at = ~U[2025-01-02 03:04:05.123456Z]

      orchestrator =
        start_orchestrator(%{
          running: [
            %{
              issue_id: "issue-3",
              identifier: "ENG-3",
              state: :running,
              session_id: "session-3",
              started_at: started_at,
              turn_count: 0,
              last_codex_event: nil,
              last_codex_message: nil,
              last_codex_timestamp: nil,
              codex_input_tokens: 0,
              codex_output_tokens: 0,
              codex_total_tokens: 0
            }
          ],
          retrying: [
            %{
              issue_id: "issue-3",
              identifier: "ENG-3",
              attempt: 2,
              due_in_ms: 120_000,
              error: %{message: "still retrying"}
            }
          ],
          codex_totals: %{},
          rate_limits: %{}
        })

      assert {:ok, %{status: "running", running: %{}, retry: %{}, attempts: attempts}} =
               Presenter.issue_payload("ENG-3", orchestrator, 25)

      assert attempts.restart_count == 1
      assert attempts.current_retry_attempt == 2
    end

    test "returns issue_not_found when issue is absent" do
      orchestrator = start_orchestrator(%{running: [], retrying: [], codex_totals: %{}, rate_limits: %{}})

      assert {:error, :issue_not_found} = Presenter.issue_payload("ENG-404", orchestrator, 25)
    end
  end

  describe "refresh_payload/1" do
    test "returns payload with ISO8601 requested_at on success" do
      requested_at = DateTime.from_naive!(~N[2025-01-02 03:04:05.123456], "Etc/UTC")
      orchestrator = start_orchestrator(%{}, %{requested_at: requested_at, source: :api})

      assert {:ok, %{requested_at: iso_requested_at, source: :api}} = Presenter.refresh_payload(orchestrator)
      assert_iso8601!(iso_requested_at)
    end

    test "returns unavailable error when orchestrator is unavailable" do
      orchestrator = start_orchestrator(%{}, :unavailable)

      assert {:error, :unavailable} = Presenter.refresh_payload(orchestrator)
    end
  end

  defp start_orchestrator(snapshot, refresh \\ :unavailable) do
    name = Module.concat(__MODULE__, "Orchestrator#{System.unique_integer([:positive])}")

    start_supervised!({StaticOrchestrator, name: name, snapshot: snapshot, refresh: refresh})

    name
  end

  defp assert_iso8601!(value) when is_binary(value) do
    assert {:ok, _datetime, 0} = DateTime.from_iso8601(value)
  end
end
