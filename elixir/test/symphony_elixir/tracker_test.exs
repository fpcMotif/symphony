defmodule SymphonyElixir.TrackerTest.StubAdapter do
  @behaviour SymphonyElixir.Tracker

  def fetch_candidate_issues do
    send(self(), :fetch_candidate_issues)
    get_mocked_response(:fetch_candidate_issues, {:ok, []})
  end

  def fetch_issues_by_states(states) do
    send(self(), {:fetch_issues_by_states, states})
    get_mocked_response(:fetch_issues_by_states, {:ok, []})
  end

  def fetch_issue_states_by_ids(ids) do
    send(self(), {:fetch_issue_states_by_ids, ids})
    get_mocked_response(:fetch_issue_states_by_ids, {:ok, []})
  end

  def create_comment(issue_id, body) do
    send(self(), {:create_comment, issue_id, body})
    get_mocked_response(:create_comment, :ok)
  end

  def update_issue_state(issue_id, state) do
    send(self(), {:update_issue_state, issue_id, state})
    get_mocked_response(:update_issue_state, :ok)
  end

  defp get_mocked_response(key, default) do
    case Process.get(key) do
      nil -> default
      value -> value
    end
  end
end

defmodule SymphonyElixir.TrackerTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Tracker
  alias SymphonyElixir.TrackerTest.StubAdapter

  setup do
    write_workflow_file!("test_workflow.yml")
    Application.put_env(:symphony_elixir, :tracker_adapter_module, StubAdapter)

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :tracker_adapter_module)
    end)

    :ok
  end

  describe "fetch_candidate_issues/0" do
    test "delegates to adapter and normalizes valid list response" do
      Process.put(:fetch_candidate_issues, {:ok, ["issue1", "issue2"]})

      assert {:ok, ["issue1", "issue2"]} = Tracker.fetch_candidate_issues()
      assert_received :fetch_candidate_issues
    end

    test "passes through error from adapter" do
      Process.put(:fetch_candidate_issues, {:error, :adapter_failed})

      assert {:error, :adapter_failed} = Tracker.fetch_candidate_issues()
      assert_received :fetch_candidate_issues
    end

    test "normalizes invalid response format" do
      Process.put(:fetch_candidate_issues, :ok)

      assert {:error, {:invalid_adapter_response, :fetch_candidate_issues}} = Tracker.fetch_candidate_issues()
      assert_received :fetch_candidate_issues
    end
  end

  describe "fetch_issues_by_states/1" do
    test "normalizes states and delegates to adapter" do
      Process.put(:fetch_issues_by_states, {:ok, ["issue1"]})

      assert {:ok, ["issue1"]} = Tracker.fetch_issues_by_states(["  Todo  ", "", "In Progress", 123])

      assert_received {:fetch_issues_by_states, ["Todo", "In Progress"]}
    end

    test "passes through error from adapter" do
      Process.put(:fetch_issues_by_states, {:error, :timeout})

      assert {:error, :timeout} = Tracker.fetch_issues_by_states(["Todo"])
      assert_received {:fetch_issues_by_states, ["Todo"]}
    end

    test "normalizes invalid response format" do
      Process.put(:fetch_issues_by_states, "not a tuple")

      assert {:error, {:invalid_adapter_response, :fetch_issues_by_states}} = Tracker.fetch_issues_by_states(["Todo"])
      assert_received {:fetch_issues_by_states, ["Todo"]}
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "normalizes ids and delegates to adapter" do
      Process.put(:fetch_issue_states_by_ids, {:ok, ["state1"]})

      assert {:ok, ["state1"]} = Tracker.fetch_issue_states_by_ids(["  123  ", "", "456", :invalid])

      assert_received {:fetch_issue_states_by_ids, ["123", "456"]}
    end

    test "normalizes invalid response format" do
      Process.put(:fetch_issue_states_by_ids, {:ok, "not a list"})

      assert {:error, {:invalid_adapter_response, :fetch_issue_states_by_ids}} = Tracker.fetch_issue_states_by_ids(["123"])
      assert_received {:fetch_issue_states_by_ids, ["123"]}
    end
  end

  describe "create_comment/2" do
    test "normalizes inputs and delegates to adapter" do
      Process.put(:create_comment, :ok)

      assert :ok = Tracker.create_comment("  issue1  ", "  my comment  ")
      assert_received {:create_comment, "issue1", "my comment"}
    end

    test "returns error if issue_id is invalid" do
      assert {:error, :invalid_issue_id} = Tracker.create_comment("   ", "my comment")
      refute_received {:create_comment, _, _}
    end

    test "returns error if body is invalid" do
      assert {:error, :invalid_comment_body} = Tracker.create_comment("issue1", "   ")
      refute_received {:create_comment, _, _}
    end

    test "passes through error from adapter" do
      Process.put(:create_comment, {:error, :forbidden})

      assert {:error, :forbidden} = Tracker.create_comment("issue1", "my comment")
    end

    test "normalizes invalid response format" do
      Process.put(:create_comment, "not ok")

      assert {:error, {:invalid_adapter_response, :create_comment}} = Tracker.create_comment("issue1", "my comment")
    end
  end

  describe "update_issue_state/2" do
    test "normalizes inputs and delegates to adapter" do
      Process.put(:update_issue_state, :ok)

      assert :ok = Tracker.update_issue_state("  issue1  ", "  Done  ")
      assert_received {:update_issue_state, "issue1", "Done"}
    end

    test "returns error if issue_id is invalid" do
      assert {:error, :invalid_issue_id} = Tracker.update_issue_state("   ", "Done")
      refute_received {:update_issue_state, _, _}
    end

    test "returns error if state_name is invalid" do
      assert {:error, :invalid_state_name} = Tracker.update_issue_state("issue1", "   ")
      refute_received {:update_issue_state, _, _}
    end

    test "passes through error from adapter" do
      Process.put(:update_issue_state, {:error, :not_found})

      assert {:error, :not_found} = Tracker.update_issue_state("issue1", "Done")
    end

    test "normalizes invalid response format" do
      Process.put(:update_issue_state, {:ok, "unexpected tuple"})

      assert {:error, {:invalid_adapter_response, :update_issue_state}} = Tracker.update_issue_state("issue1", "Done")
    end
  end
end
