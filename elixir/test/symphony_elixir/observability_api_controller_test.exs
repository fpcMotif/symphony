defmodule SymphonyElixir.ObservabilityApiControllerTest do
  use SymphonyElixir.TestSupport

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

  setup do
    endpoint_config = Application.get_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, [])

    on_exit(fn ->
      Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)
    end)

    :ok
  end

  test "serves state, issue, and refresh payloads over HTTP" do
    orchestrator_name = Module.concat(__MODULE__, :HappyPathOrchestrator)

    start_supervised!({StaticOrchestrator, name: orchestrator_name, snapshot: snapshot_fixture(), refresh: refresh_fixture()})

    port = start_test_endpoint(orchestrator_name)

    state_response = Req.get!("http://127.0.0.1:#{port}/api/v1/state")
    assert state_response.status == 200
    assert state_response.body["counts"] == %{"running" => 1, "retrying" => 1}

    issue_response = Req.get!("http://127.0.0.1:#{port}/api/v1/MT-HTTP")
    assert issue_response.status == 200
    assert issue_response.body["issue_identifier"] == "MT-HTTP"
    assert issue_response.body["status"] == "running"

    refresh_response = Req.post!("http://127.0.0.1:#{port}/api/v1/refresh", json: %{})
    assert refresh_response.status == 202
    assert refresh_response.body["queued"] == true
    assert refresh_response.body["operations"] == ["poll"]
  end

  test "returns issue_not_found when issue is missing" do
    orchestrator_name = Module.concat(__MODULE__, :IssueMissingOrchestrator)
    start_supervised!({StaticOrchestrator, name: orchestrator_name, snapshot: snapshot_fixture()})

    port = start_test_endpoint(orchestrator_name)

    response = Req.get!("http://127.0.0.1:#{port}/api/v1/MT-UNKNOWN")

    assert response.status == 404
    assert response.body["error"]["code"] == "issue_not_found"
  end

  test "returns orchestrator_unavailable when refresh cannot be queued" do
    orchestrator_name = Module.concat(__MODULE__, :RefreshUnavailableOrchestrator)

    start_supervised!({StaticOrchestrator, name: orchestrator_name, snapshot: snapshot_fixture(), refresh: :unavailable})

    port = start_test_endpoint(orchestrator_name)

    response = Req.post!("http://127.0.0.1:#{port}/api/v1/refresh", json: %{})

    assert response.status == 503
    assert response.body["error"]["code"] == "orchestrator_unavailable"
  end

  test "returns method_not_allowed for disallowed verbs" do
    orchestrator_name = Module.concat(__MODULE__, :MethodGuardOrchestrator)
    start_supervised!({StaticOrchestrator, name: orchestrator_name, snapshot: snapshot_fixture()})

    port = start_test_endpoint(orchestrator_name)

    assert_method_not_allowed(Req.post!("http://127.0.0.1:#{port}/api/v1/state", json: %{}))
    assert_method_not_allowed(Req.get!("http://127.0.0.1:#{port}/api/v1/refresh"))
    assert_method_not_allowed(Req.put!("http://127.0.0.1:#{port}/api/v1/MT-HTTP", json: %{}))
    assert_method_not_allowed(Req.post!("http://127.0.0.1:#{port}/api/v1/MT-HTTP", json: %{}))
  end

  test "returns not_found for unknown routes" do
    orchestrator_name = Module.concat(__MODULE__, :NotFoundRouteOrchestrator)
    start_supervised!({StaticOrchestrator, name: orchestrator_name, snapshot: snapshot_fixture()})

    port = start_test_endpoint(orchestrator_name)

    response = Req.get!("http://127.0.0.1:#{port}/api/v1/unknown/path")

    assert response.status == 404
    assert response.body["error"]["code"] == "not_found"
  end

  defp start_test_endpoint(orchestrator_name) do
    endpoint_config =
      :symphony_elixir
      |> Application.get_env(SymphonyElixirWeb.Endpoint, [])
      |> Keyword.merge(
        server: true,
        secret_key_base: String.duplicate("s", 64),
        http: [ip: {127, 0, 0, 1}, port: 0],
        orchestrator: orchestrator_name,
        snapshot_timeout_ms: 50
      )

    Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)
    start_supervised!({SymphonyElixirWeb.Endpoint, []})

    wait_for_port()
  end

  defp wait_for_port(attempts \\ 20)

  defp wait_for_port(attempts) when attempts > 0 do
    case SymphonyElixirWeb.Endpoint.server_info(:http) do
      %{port: port} when is_integer(port) and port > 0 ->
        port

      _other ->
        Process.sleep(10)
        wait_for_port(attempts - 1)
    end
  end

  defp wait_for_port(0) do
    flunk("endpoint did not bind to an HTTP port")
  end

  defp assert_method_not_allowed(response) do
    assert response.status == 405
    assert response.body["error"]["code"] == "method_not_allowed"
  end

  defp snapshot_fixture do
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

  defp refresh_fixture do
    %{
      queued: true,
      coalesced: false,
      requested_at: DateTime.utc_now(),
      operations: ["poll"]
    }
  end
end
