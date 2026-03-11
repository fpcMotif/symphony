defmodule SymphonyElixir.ObservabilityE2ETest do
  use SymphonyElixir.TestSupport

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint SymphonyElixirWeb.Endpoint
  @moduletag :integration

  defmodule DeterministicOrchestrator do
    use GenServer

    def start_link(opts) do
      name = Keyword.fetch!(opts, :name)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def set_snapshot(name, snapshot) do
      GenServer.call(name, {:set_snapshot, snapshot})
    end

    @impl true
    def init(opts), do: {:ok, %{snapshot: Keyword.fetch!(opts, :snapshot)}}

    @impl true
    def handle_call(:snapshot, _from, state), do: {:reply, state.snapshot, state}

    @impl true
    def handle_call(:request_refresh, _from, state), do: {:reply, :unavailable, state}

    @impl true
    def handle_call({:set_snapshot, snapshot}, _from, state) do
      {:reply, :ok, %{state | snapshot: snapshot}}
    end
  end

  setup do
    endpoint_config = Application.get_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, [])

    on_exit(fn ->
      Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)
    end)

    :ok
  end

  test "observability API and dashboard stay consistent across snapshot updates" do
    orchestrator_name = Module.concat(__MODULE__, :IntegrationOrchestrator)

    initial_snapshot = %{
      running: [
        %{
          issue_id: "issue-424",
          identifier: "MT-424",
          state: "In Progress",
          session_id: "thread-424",
          turn_count: 3,
          last_codex_event: :notification,
          last_codex_message: "booted",
          last_codex_timestamp: DateTime.utc_now(),
          codex_input_tokens: 11,
          codex_output_tokens: 7,
          codex_total_tokens: 18,
          started_at: DateTime.utc_now()
        }
      ],
      retrying: [
        %{
          issue_id: "issue-900",
          identifier: "MT-900",
          attempt: 2,
          due_in_ms: 5_000,
          error: "retry scheduled"
        }
      ],
      codex_totals: %{input_tokens: 11, output_tokens: 7, total_tokens: 18, seconds_running: 12},
      rate_limits: %{"primary" => %{"remaining" => 9}}
    }

    start_supervised!({DeterministicOrchestrator, name: orchestrator_name, snapshot: initial_snapshot})

    start_test_endpoint(orchestrator: orchestrator_name, snapshot_timeout_ms: 50)

    initial_api_payload = json_response(get(build_conn(), "/api/v1/state"), 200)
    assert initial_api_payload["counts"] == %{"running" => 1, "retrying" => 1}
    assert Enum.map(initial_api_payload["running"], & &1["issue_identifier"]) == ["MT-424"]
    assert Enum.map(initial_api_payload["retrying"], & &1["issue_identifier"]) == ["MT-900"]

    {:ok, view, initial_html} = live(build_conn(), "/")
    assert initial_html =~ "Operations Dashboard"
    assert initial_html =~ "MT-424"
    assert initial_html =~ "MT-900"
    assert initial_html =~ "metric-label\">Running"
    assert initial_html =~ "metric-value numeric\">1"

    updated_snapshot = %{
      running: [
        %{
          issue_id: "issue-424",
          identifier: "MT-424",
          state: "In Progress",
          session_id: "thread-424",
          turn_count: 4,
          last_codex_event: :notification,
          last_codex_message: %{
            event: :notification,
            message: %{
              payload: %{
                "method" => "codex/event/agent_message_content_delta",
                "params" => %{"msg" => %{"content" => "updated from integration test"}}
              }
            }
          },
          last_codex_timestamp: DateTime.utc_now(),
          codex_input_tokens: 20,
          codex_output_tokens: 13,
          codex_total_tokens: 33,
          started_at: DateTime.utc_now()
        },
        %{
          issue_id: "issue-425",
          identifier: "MT-425",
          state: "In Progress",
          session_id: "thread-425",
          turn_count: 1,
          last_codex_event: :notification,
          last_codex_message: "started",
          last_codex_timestamp: DateTime.utc_now(),
          codex_input_tokens: 3,
          codex_output_tokens: 2,
          codex_total_tokens: 5,
          started_at: DateTime.utc_now()
        }
      ],
      retrying: [],
      codex_totals: %{input_tokens: 23, output_tokens: 15, total_tokens: 38, seconds_running: 20},
      rate_limits: %{"primary" => %{"remaining" => 8}}
    }

    :ok = DeterministicOrchestrator.set_snapshot(orchestrator_name, updated_snapshot)
    StatusDashboard.notify_update()

    assert_eventually(fn ->
      updated_api_payload = json_response(get(build_conn(), "/api/v1/state"), 200)

      updated_api_payload["counts"] == %{"running" => 2, "retrying" => 0} and
        Enum.map(updated_api_payload["running"], & &1["issue_identifier"]) == ["MT-424", "MT-425"] and
        updated_api_payload["codex_totals"]["total_tokens"] == 38 and
        hd(updated_api_payload["running"])["last_message"] =~
          "agent message content streaming: updated from integration test"
    end)

    assert_eventually(fn ->
      updated_html = render(view)

      updated_html =~ "MT-424" and
        updated_html =~ "MT-425" and
        updated_html =~ "agent message content streaming: updated from integration test" and
        updated_html =~ "metric-value numeric\">2" and
        updated_html =~ "metric-value numeric\">0" and
        updated_html =~ "Total: 33"
    end)
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
