defmodule SymphonyElixir.OrchestrationE2ETest.FakeLinearClient do
  alias SymphonyElixir.Linear.Issue

  @table :orchestration_e2e_fake_linear

  def reset!(opts) do
    if :ets.whereis(@table) != :undefined, do: :ets.delete(@table)

    :ets.new(@table, [:named_table, :public, :set])

    :ets.insert(@table, {:recipient, Keyword.get(opts, :recipient)})
    :ets.insert(@table, {:candidate_responses, Keyword.get(opts, :candidate_responses, [{:ok, []}])})
    :ets.insert(@table, {:candidate_call_count, 0})
    :ets.insert(@table, {:issue_state_call_counts, %{}})

    issues_by_id =
      opts
      |> Keyword.get(:issues_by_id, %{})
      |> Enum.into(%{}, fn {id, issue} -> {id, normalize_issue_response(issue)} end)

    terminal_issues =
      opts
      |> Keyword.get(:terminal_issues, [])
      |> Enum.map(&normalize_issue/1)

    :ets.insert(@table, {:issues_by_id, issues_by_id})
    :ets.insert(@table, {:terminal_issues, terminal_issues})
    :ok
  end

  def candidate_call_count do
    :ets.lookup_element(@table, :candidate_call_count, 2)
  end

  def fetch_candidate_issues do
    call_count = :ets.update_counter(@table, :candidate_call_count, {2, 1})
    responses = :ets.lookup_element(@table, :candidate_responses, 2)
    response = Enum.at(responses, call_count - 1) || List.last(responses)

    send_event({:fake_linear_fetch_candidate_issues, call_count, response})

    case response do
      {:ok, issues} -> {:ok, Enum.map(issues, &normalize_issue/1)}
      {:error, _reason} = error -> error
    end
  end

  def fetch_issue_states_by_ids(issue_ids) do
    issues_by_id = :ets.lookup_element(@table, :issues_by_id, 2)
    issue_state_call_counts = :ets.lookup_element(@table, :issue_state_call_counts, 2)

    {issues, updated_call_counts} =
      Enum.map_reduce(issue_ids, issue_state_call_counts, fn issue_id, call_counts ->
        issue_response = Map.get(issues_by_id, issue_id)
        issue = next_issue_state_response(issue_id, issue_response, call_counts)
        {issue, increment_issue_state_call_count(issue_id, call_counts)}
      end)

    :ets.insert(@table, {:issue_state_call_counts, updated_call_counts})
    issues = Enum.reject(issues, &is_nil/1)

    send_event({:fake_linear_fetch_issue_states_by_ids, issue_ids, issues})
    {:ok, issues}
  end

  def fetch_issues_by_states(state_names) do
    terminal_issues = :ets.lookup_element(@table, :terminal_issues, 2)
    normalized_states = MapSet.new(Enum.map(state_names, &String.downcase/1))

    matching =
      Enum.filter(terminal_issues, fn %Issue{state: state} ->
        MapSet.member?(normalized_states, String.downcase(state))
      end)

    send_event({:fake_linear_fetch_issues_by_states, state_names, matching})
    {:ok, matching}
  end

  def graphql(_query, _variables, _opts \\ []), do: {:ok, %{"data" => %{}}}

  defp send_event(message) do
    case :ets.lookup_element(@table, :recipient, 2) do
      pid when is_pid(pid) -> send(pid, message)
      _ -> :ok
    end
  end

  defp normalize_issue(%Issue{} = issue), do: issue

  defp normalize_issue(attrs) when is_map(attrs) do
    struct(Issue, attrs)
  end

  defp normalize_issue_response(issues) when is_list(issues) do
    Enum.map(issues, &normalize_issue/1)
  end

  defp normalize_issue_response(issue), do: normalize_issue(issue)

  defp next_issue_state_response(issue_id, issues, call_counts) when is_list(issues) do
    call_count = Map.get(call_counts, issue_id, 0)
    Enum.at(issues, call_count) || List.last(issues)
  end

  defp next_issue_state_response(_issue_id, issue, _call_counts), do: issue

  defp increment_issue_state_call_count(issue_id, call_counts) do
    Map.update(call_counts, issue_id, 1, &(&1 + 1))
  end
end

defmodule SymphonyElixir.OrchestrationE2ETest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.OrchestrationE2ETest.FakeLinearClient

  @moduletag :e2e

  setup do
    original_linear_client_module = Application.get_env(:symphony_elixir, :linear_client_module)

    on_exit(fn ->
      if original_linear_client_module do
        Application.put_env(:symphony_elixir, :linear_client_module, original_linear_client_module)
      else
        Application.delete_env(:symphony_elixir, :linear_client_module)
      end
    end)

    :ok
  end

  test "happy path orchestrates a full cycle and leaves an isolated workspace" do
    issue = issue_fixture("issue-happy", "MT-E2E-1", "In Progress")
    %{test_root: test_root, workspace_root: workspace_root, codex_binary: codex_binary} = setup_runtime_paths()

    try do
      write_single_turn_codex!(codex_binary)

      FakeLinearClient.reset!(
        recipient: self(),
        candidate_responses: [{:ok, [issue]}, {:ok, []}],
        issues_by_id: %{issue.id => [issue, %{issue | state: "Done"}]},
        terminal_issues: []
      )

      Application.put_env(
        :symphony_elixir,
        :linear_client_module,
        FakeLinearClient
      )

      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "linear",
        tracker_api_token: "token",
        tracker_project_slug: "project",
        workspace_root: workspace_root,
        codex_command: "#{codex_binary} app-server",
        poll_interval_ms: 60_000,
        max_turns: 1
      )

      assert :ok = WorkflowStore.force_reload()

      orchestrator_name = Module.concat(__MODULE__, :HappyPathOrchestrator)
      {:ok, pid} = Orchestrator.start_link(name: orchestrator_name)
      on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :normal) end)

      _ = Orchestrator.request_refresh(orchestrator_name)

      workspace = Path.join(workspace_root, issue.identifier)
      assert_eventually(fn -> File.dir?(workspace) end)
      assert_receive {:fake_linear_fetch_candidate_issues, 1, {:ok, [_issue]}}, 5_000

      assert_eventually(fn ->
        snapshot = Orchestrator.snapshot(orchestrator_name, 1_000)
        snapshot != :timeout and snapshot.retrying == [] and snapshot.running == []
      end)

      assert FakeLinearClient.candidate_call_count() >= 2
      assert File.exists?(Path.join(workspace, ".agent-result"))
    after
      File.rm_rf(test_root)
    end
  end

  test "transient tracker failure retries with backoff and eventually recovers" do
    issue = issue_fixture("issue-retry", "MT-E2E-2", "In Progress")
    %{test_root: test_root, workspace_root: workspace_root, codex_binary: codex_binary} = setup_runtime_paths()

    try do
      write_single_turn_codex!(codex_binary)

      FakeLinearClient.reset!(
        recipient: self(),
        candidate_responses: [
          {:ok, [issue]},
          {:error, :temporary_unavailable},
          {:ok, []}
        ],
        issues_by_id: %{issue.id => [issue, issue, %{issue | state: "Done"}]},
        terminal_issues: []
      )

      Application.put_env(
        :symphony_elixir,
        :linear_client_module,
        FakeLinearClient
      )

      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "linear",
        tracker_api_token: "token",
        tracker_project_slug: "project",
        workspace_root: workspace_root,
        codex_command: "#{codex_binary} app-server",
        poll_interval_ms: 60_000,
        max_turns: 1
      )

      assert :ok = WorkflowStore.force_reload()

      orchestrator_name = Module.concat(__MODULE__, :RetryOrchestrator)
      {:ok, pid} = Orchestrator.start_link(name: orchestrator_name)
      on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :normal) end)

      _ = Orchestrator.request_refresh(orchestrator_name)

      assert_eventually(fn ->
        snapshot = Orchestrator.snapshot(orchestrator_name, 1_000)
        snapshot != :timeout and snapshot.retrying != []
      end)

      send(pid, {:retry_issue, issue.id})

      assert_eventually(fn ->
        snapshot = Orchestrator.snapshot(orchestrator_name, 1_000)

        Enum.any?(snapshot.retrying, fn retry ->
          retry.issue_id == issue.id and retry.attempt == 2 and retry.due_in_ms >= 15_000
        end)
      end)

      send(pid, {:retry_issue, issue.id})

      assert_eventually(fn ->
        snapshot = Orchestrator.snapshot(orchestrator_name, 1_000)
        snapshot.retrying == [] and snapshot.running == []
      end)

      assert FakeLinearClient.candidate_call_count() == 3
    after
      File.rm_rf(test_root)
    end
  end

  defp setup_runtime_paths do
    test_root = Path.join(System.tmp_dir!(), "symphony-elixir-orchestration-e2e-#{System.unique_integer([:positive])}")
    workspace_root = Path.join(test_root, "workspaces")
    codex_binary = Path.join(test_root, "fake-codex")

    File.mkdir_p!(workspace_root)

    %{test_root: test_root, workspace_root: workspace_root, codex_binary: codex_binary}
  end

  defp write_single_turn_codex!(path) do
    File.write!(path, """
    #!/bin/sh
    count=0
    while IFS= read -r _line; do
      count=$((count + 1))
      case "$count" in
        1)
          printf '%s\\n' '{"id":1,"result":{}}'
          ;;
        2)
          ;;
        3)
          printf '%s\\n' '{"id":2,"result":{"thread":{"id":"thread-e2e"}}}'
          ;;
        4)
          printf '%s\\n' '{"id":3,"result":{"turn":{"id":"turn-e2e"}}}'
          : > .agent-result
          trap "" PIPE
          printf '%s\\n' '{"method":"turn/completed"}'
          : > .agent-result
          break
          ;;
      esac
    done
    """)

    File.chmod!(path, 0o755)
  end

  defp issue_fixture(id, identifier, state) do
    %Issue{
      id: id,
      identifier: identifier,
      title: "Orchestration e2e",
      description: "Exercise orchestrator across components",
      state: state,
      url: "https://example.test/issues/#{identifier}",
      labels: []
    }
  end

  defp assert_eventually(fun, timeout_ms \\ 5_000)

  defp assert_eventually(fun, timeout_ms) when is_function(fun, 0) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_assert_eventually(fun, deadline)
  end

  defp do_assert_eventually(fun, deadline) do
    if fun.() do
      assert true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("condition did not become true before timeout")
      else
        Process.sleep(20)
        do_assert_eventually(fun, deadline)
      end
    end
  end
end
