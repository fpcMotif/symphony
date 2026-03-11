defmodule SymphonyElixirWeb.ObservabilityApiContractTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  @endpoint SymphonyElixirWeb.Endpoint

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

  setup do
    endpoint_config = Application.get_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, [])

    on_exit(fn ->
      stop_test_endpoint()
      Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)
    end)

    :ok
  end

  test "GET /api/v1/state returns expected contract keys" do
    orchestrator_name = Module.concat(__MODULE__, :StateOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot())
    start_test_endpoint(orchestrator: orchestrator_name, snapshot_timeout_ms: 50)

    payload = json_response(get(build_conn(), "/api/v1/state"), 200)

    assert Map.has_key?(payload, "generated_at")
    assert Map.has_key?(payload, "counts")
    assert Map.has_key?(payload, "running")
    assert Map.has_key?(payload, "retrying")
    assert Map.has_key?(payload, "codex_totals")
    assert Map.has_key?(payload, "rate_limits")
    assert Map.has_key?(payload["counts"], "running")
    assert Map.has_key?(payload["counts"], "retrying")
    assert Map.has_key?(hd(payload["running"]), "issue_identifier")
    assert Map.has_key?(hd(payload["running"]), "session_id")
    assert Map.has_key?(hd(payload["running"]), "tokens")
    assert Map.has_key?(hd(payload["retrying"]), "attempt")
    assert Map.has_key?(hd(payload["retrying"]), "due_at")
  end

  test "POST /api/v1/refresh returns 202 when available and 503 when unavailable" do
    available_name = Module.concat(__MODULE__, :RefreshAvailableOrchestrator)

    {:ok, _pid} =
      StaticOrchestrator.start_link(
        name: available_name,
        snapshot: snapshot(),
        refresh: %{queued: true, coalesced: false, requested_at: DateTime.utc_now(), operations: ["poll"]}
      )

    start_test_endpoint(orchestrator: available_name, snapshot_timeout_ms: 50)

    accepted_payload = json_response(post(build_conn(), "/api/v1/refresh", %{}), 202)

    assert Map.has_key?(accepted_payload, "queued")
    assert Map.has_key?(accepted_payload, "coalesced")
    assert Map.has_key?(accepted_payload, "requested_at")
    assert Map.has_key?(accepted_payload, "operations")

    unavailable_name = Module.concat(__MODULE__, :RefreshUnavailableOrchestrator)
    start_test_endpoint(orchestrator: unavailable_name, snapshot_timeout_ms: 50)

    assert json_response(post(build_conn(), "/api/v1/refresh", %{}), 503) == %{
             "error" => %{
               "code" => "orchestrator_unavailable",
               "message" => "Orchestrator is unavailable"
             }
           }
  end

  test "GET /api/v1/:issue_identifier returns 200 for known issue and 404 for unknown issue" do
    orchestrator_name = Module.concat(__MODULE__, :IssueOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot())
    start_test_endpoint(orchestrator: orchestrator_name, snapshot_timeout_ms: 50)

    issue_payload = json_response(get(build_conn(), "/api/v1/MT-API"), 200)

    assert Map.has_key?(issue_payload, "issue_identifier")
    assert Map.has_key?(issue_payload, "issue_id")
    assert Map.has_key?(issue_payload, "status")
    assert Map.has_key?(issue_payload, "workspace")
    assert Map.has_key?(issue_payload, "attempts")
    assert Map.has_key?(issue_payload, "running")
    assert Map.has_key?(issue_payload, "retry")
    assert Map.has_key?(issue_payload, "logs")
    assert Map.has_key?(issue_payload, "recent_events")
    assert Map.has_key?(issue_payload, "tracked")

    assert json_response(get(build_conn(), "/api/v1/MT-MISSING"), 404) == %{
             "error" => %{"code" => "issue_not_found", "message" => "Issue not found"}
           }
  end

  test "method-not-allowed matrix for observability API routes" do
    orchestrator_name = Module.concat(__MODULE__, :MethodMatrixOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot())
    start_test_endpoint(orchestrator: orchestrator_name, snapshot_timeout_ms: 50)

    for method <- [:post, :put, :patch, :delete, :options] do
      assert json_response(request(method, "/api/v1/state"), 405) == method_not_allowed_error()
    end

    for method <- [:get, :put, :patch, :delete, :options] do
      assert json_response(request(method, "/api/v1/refresh"), 405) == method_not_allowed_error()
    end

    for method <- [:post, :put, :patch, :delete, :options] do
      assert json_response(request(method, "/api/v1/MT-API"), 405) == method_not_allowed_error()
    end
  end

  test "unknown routes return not_found contract" do
    orchestrator_name = Module.concat(__MODULE__, :NotFoundOrchestrator)
    {:ok, _pid} = StaticOrchestrator.start_link(name: orchestrator_name, snapshot: snapshot())
    start_test_endpoint(orchestrator: orchestrator_name, snapshot_timeout_ms: 50)

    assert json_response(get(build_conn(), "/unknown/path"), 404) == %{
             "error" => %{"code" => "not_found", "message" => "Route not found"}
           }
  end

  defp request(method, path) when method in [:post, :put, :patch] do
    case method do
      :post -> post(build_conn(), path, %{})
      :put -> put(build_conn(), path, %{})
      :patch -> patch(build_conn(), path, %{})
    end
  end

  defp request(method, path) do
    case method do
      :get -> get(build_conn(), path)
      :delete -> delete(build_conn(), path)
      :options -> options(build_conn(), path)
    end
  end

  defp method_not_allowed_error do
    %{"error" => %{"code" => "method_not_allowed", "message" => "Method not allowed"}}
  end

  defp start_test_endpoint(overrides) do
    case stop_supervised(SymphonyElixirWeb.Endpoint) do
      :ok -> :ok
      {:error, _reason} -> :ok
    end

    stop_test_endpoint()

    endpoint_config =
      :symphony_elixir
      |> Application.get_env(SymphonyElixirWeb.Endpoint, [])
      |> Keyword.merge(server: false, secret_key_base: String.duplicate("s", 64))
      |> Keyword.merge(overrides)

    Application.put_env(:symphony_elixir, SymphonyElixirWeb.Endpoint, endpoint_config)
    start_supervised!({SymphonyElixirWeb.Endpoint, []})
  end

  defp stop_test_endpoint do
    case Process.whereis(SymphonyElixirWeb.Endpoint) do
      pid when is_pid(pid) ->
        Process.unlink(pid)

        ref = Process.monitor(pid)
        Process.exit(pid, :shutdown)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          1_000 -> :ok
        end

      _ ->
        :ok
    end
  end

  defp snapshot do
    %{
      running: [
        %{
          issue_id: "issue-api",
          identifier: "MT-API",
          state: "In Progress",
          session_id: "session-api",
          turn_count: 3,
          codex_input_tokens: 10,
          codex_output_tokens: 7,
          codex_total_tokens: 17,
          started_at: DateTime.utc_now(),
          last_codex_event: :notification,
          last_codex_message: "working",
          last_codex_timestamp: DateTime.utc_now()
        }
      ],
      retrying: [
        %{
          issue_id: "issue-retry",
          identifier: "MT-RETRY",
          attempt: 2,
          due_in_ms: 5_000,
          error: "transient"
        }
      ],
      codex_totals: %{input_tokens: 10, output_tokens: 7, total_tokens: 17, seconds_running: 13.2},
      rate_limits: %{"primary" => %{"remaining" => 11}}
    }
  end
end
