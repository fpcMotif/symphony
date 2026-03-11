defmodule SymphonyElixir.TrackerContractLinearClientStub do
  @moduledoc false

  def fetch_candidate_issues do
    notify({:fetch_candidate_issues})
    response(:fetch_candidate_issues, {:ok, []})
  end

  def fetch_issues_by_states(states) do
    notify({:fetch_issues_by_states, states})
    response(:fetch_issues_by_states, {:ok, []})
  end

  def fetch_issue_states_by_ids(ids) do
    notify({:fetch_issue_states_by_ids, ids})
    response(:fetch_issue_states_by_ids, {:ok, []})
  end

  def graphql(query, variables, _opts \\ []) do
    notify({:graphql, query, variables})

    cond do
      String.contains?(query, "commentCreate") ->
        response(:graphql_comment, {:ok, %{"data" => %{"commentCreate" => %{"success" => true}}}})

      String.contains?(query, "SymphonyResolveStateId") ->
        response(:graphql_state_lookup, {:ok, %{"data" => %{"issue" => %{"team" => %{"states" => %{"nodes" => [%{"id" => "state-1"}]}}}}}})

      String.contains?(query, "issueUpdate") ->
        response(:graphql_state_update, {:ok, %{"data" => %{"issueUpdate" => %{"success" => true}}}})

      true ->
        {:error, :unexpected_query}
    end
  end

  defp notify(message) do
    case Application.get_env(:symphony_elixir, :tracker_contract_test_pid) do
      pid when is_pid(pid) -> send(pid, message)
      _ -> :ok
    end
  end

  defp response(key, default) do
    Application.get_env(:symphony_elixir, :tracker_contract_stub_responses, %{})
    |> Map.get(key, default)
  end
end

defmodule SymphonyElixir.TrackerContractInvalidAdapterStub do
  @moduledoc false

  def fetch_candidate_issues, do: {:ok, []}
  def fetch_issues_by_states(_states), do: {:ok, []}
  def fetch_issue_states_by_ids(_ids), do: {:ok, []}
  def create_comment(_issue_id, _body), do: :wat
  def update_issue_state(_issue_id, _state_name), do: {:unexpected, :shape}
end

defmodule SymphonyElixir.TrackerContractTest do
  use SymphonyElixir.TestSupport

  setup do
    Application.put_env(:symphony_elixir, :tracker_contract_test_pid, self())

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :tracker_adapter_module)
      Application.delete_env(:symphony_elixir, :linear_client_module)
      Application.delete_env(:symphony_elixir, :tracker_contract_stub_responses)
      Application.delete_env(:symphony_elixir, :tracker_contract_test_pid)
    end)

    :ok
  end

  describe "memory adapter contract" do
    test "normalizes malformed inputs for read APIs" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")

      issue = %Issue{id: "I-1", state: "In Progress"}
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [issue])

      assert {:ok, [^issue]} = Tracker.fetch_issues_by_states(["  in progress  ", 123, ""])
      assert {:ok, [^issue]} = Tracker.fetch_issue_states_by_ids(["I-1", nil, "  "])
      assert {:ok, [^issue]} = Tracker.fetch_candidate_issues()
    end

    test "returns explicit validation errors for blank write inputs" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")

      assert {:error, :invalid_issue_id} = Tracker.create_comment("   ", "body")
      assert {:error, :invalid_comment_body} = Tracker.create_comment("issue-1", "   ")
      assert {:error, :invalid_issue_id} = Tracker.update_issue_state("", "Done")
      assert {:error, :invalid_state_name} = Tracker.update_issue_state("issue-1", "\n\t")
    end

    test "returns explicit validation errors for non-binary write inputs" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")

      assert {:error, :invalid_issue_id} = Tracker.create_comment(123, "body")
      assert {:error, :invalid_comment_body} = Tracker.create_comment("issue-1", :body)
      assert {:error, :invalid_issue_id} = Tracker.update_issue_state([], "Done")
      assert {:error, :invalid_state_name} = Tracker.update_issue_state("issue-1", %{state: "Done"})
    end

    test "rejects non-list inputs for read APIs" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")

      assert {:error, :invalid_states} = Tracker.fetch_issues_by_states("Todo")
      assert {:error, :invalid_issue_ids} = Tracker.fetch_issue_states_by_ids(%{id: "I-1"})
    end
  end

  describe "linear adapter contract" do
    test "normalizes malformed inputs before delegating" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "linear")
      Application.put_env(:symphony_elixir, :linear_client_module, SymphonyElixir.TrackerContractLinearClientStub)

      assert {:ok, []} = Tracker.fetch_issues_by_states([" Todo ", :done, "", 123, "In Progress"])
      assert_receive {:fetch_issues_by_states, ["Todo", "In Progress"]}

      assert {:ok, []} = Tracker.fetch_issue_states_by_ids([" issue-1 ", nil, "", 7])
      assert_receive {:fetch_issue_states_by_ids, ["issue-1"]}

      assert :ok = Tracker.create_comment(" issue-1 ", " hello ")
      assert_receive {:graphql, query, %{body: "hello", issueId: "issue-1"}}
      assert query =~ "commentCreate"

      assert :ok = Tracker.update_issue_state(" issue-1 ", " Done ")
      assert_receive {:graphql, lookup_query, %{issueId: "issue-1", stateName: "Done"}}
      assert lookup_query =~ "SymphonyResolveStateId"
      assert_receive {:graphql, update_query, %{issueId: "issue-1", stateId: "state-1"}}
      assert update_query =~ "issueUpdate"
    end

    test "normalizes unexpected adapter responses into consistent errors" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "linear")
      Application.put_env(:symphony_elixir, :linear_client_module, SymphonyElixir.TrackerContractLinearClientStub)

      Application.put_env(:symphony_elixir, :tracker_contract_stub_responses, %{
        fetch_candidate_issues: {:ok, :not_a_list},
        fetch_issues_by_states: {:bad, :shape},
        fetch_issue_states_by_ids: :ok,
        graphql_comment: :wat,
        graphql_state_lookup: :bad,
        graphql_state_update: {:ok, %{"data" => %{"issueUpdate" => %{"success" => false}}}}
      })

      assert {:error, {:invalid_adapter_response, :fetch_candidate_issues}} = Tracker.fetch_candidate_issues()

      assert {:error, {:invalid_adapter_response, :fetch_issues_by_states}} =
               Tracker.fetch_issues_by_states(["Todo"])

      assert {:error, {:invalid_adapter_response, :fetch_issue_states_by_ids}} =
               Tracker.fetch_issue_states_by_ids(["issue-1"])

      assert {:error, :comment_create_failed} = Tracker.create_comment("issue-1", "body")
      assert {:error, :state_not_found} = Tracker.update_issue_state("issue-1", "Done")
    end

    test "passes through adapter errors after input normalization" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "linear")
      Application.put_env(:symphony_elixir, :linear_client_module, SymphonyElixir.TrackerContractLinearClientStub)

      Application.put_env(:symphony_elixir, :tracker_contract_stub_responses, %{
        fetch_candidate_issues: {:error, :temporary_unavailable},
        graphql_comment: {:error, :comment_transport_down},
        graphql_state_lookup: {:error, :state_lookup_down}
      })

      assert {:error, :temporary_unavailable} = Tracker.fetch_candidate_issues()
      assert {:error, :comment_transport_down} = Tracker.create_comment("issue-1", "body")
      assert {:error, :state_lookup_down} = Tracker.update_issue_state("issue-1", "Done")
    end

    test "normalizes invalid write adapter responses into consistent errors" do
      Application.put_env(
        :symphony_elixir,
        :tracker_adapter_module,
        SymphonyElixir.TrackerContractInvalidAdapterStub
      )

      assert {:error, {:invalid_adapter_response, :create_comment}} =
               Tracker.create_comment("issue-1", "body")

      assert {:error, {:invalid_adapter_response, :update_issue_state}} =
               Tracker.update_issue_state("issue-1", "Done")
    end
  end
end
