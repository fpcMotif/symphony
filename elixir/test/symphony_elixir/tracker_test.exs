defmodule SymphonyElixir.TrackerTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Tracker

  defmodule MockAdapter do
    @behaviour SymphonyElixir.Tracker

    def fetch_candidate_issues do
      send(self(), {:mock_fetch_candidate_issues})
      {:ok, [:issue1]}
    end

    def fetch_issues_by_states(states) do
      send(self(), {:mock_fetch_issues_by_states, states})
      {:ok, [:issue2]}
    end

    def fetch_issue_states_by_ids(ids) do
      send(self(), {:mock_fetch_issue_states_by_ids, ids})
      {:ok, [:state1]}
    end

    def create_comment(issue_id, body) do
      send(self(), {:mock_create_comment, issue_id, body})
      :ok
    end

    def update_issue_state(issue_id, state) do
      send(self(), {:mock_update_issue_state, issue_id, state})
      :ok
    end
  end

  defmodule ErrorAdapter do
    @behaviour SymphonyElixir.Tracker

    def fetch_candidate_issues, do: {:error, :fetch_failed}
    def fetch_issues_by_states(_), do: {:error, :fetch_failed}
    def fetch_issue_states_by_ids(_), do: {:error, :fetch_failed}
    def create_comment(_, _), do: {:error, :create_failed}
    def update_issue_state(_, _), do: {:error, :update_failed}
  end

  defmodule InvalidAdapter do
    @behaviour SymphonyElixir.Tracker

    def fetch_candidate_issues, do: :invalid
    def fetch_issues_by_states(_), do: :invalid
    def fetch_issue_states_by_ids(_), do: :invalid
    def create_comment(_, _), do: :invalid
    def update_issue_state(_, _), do: :invalid
  end

  setup do
    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :tracker_adapter_module)
    end)

    :ok
  end

  describe "adapter selection" do
    test "defaults to linear adapter when kind is linear" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "linear")
      assert Tracker.adapter() == SymphonyElixir.Linear.Adapter
    end

    test "returns memory adapter when kind is memory" do
      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "memory")
      assert Tracker.adapter() == SymphonyElixir.Tracker.Memory
    end

    test "returns custom adapter when kind is custom" do
      write_workflow_file!(Workflow.workflow_file_path(),
        tracker_kind: "custom",
        tracker_adapter_module: "SymphonyElixir.TrackerTest.MockAdapter"
      )

      assert Tracker.adapter() == SymphonyElixir.TrackerTest.MockAdapter
    end

    test "allows override via application env" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, SymphonyElixir.TrackerTest.MockAdapter)
      assert Tracker.adapter() == SymphonyElixir.TrackerTest.MockAdapter
    end
  end

  describe "fetch_candidate_issues/0" do
    test "delegates to adapter and returns success" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, MockAdapter)
      assert {:ok, [:issue1]} = Tracker.fetch_candidate_issues()
      assert_received {:mock_fetch_candidate_issues}
    end

    test "returns error when adapter fails" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, ErrorAdapter)
      assert {:error, :fetch_failed} = Tracker.fetch_candidate_issues()
    end

    test "normalizes invalid adapter response" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, InvalidAdapter)
      assert {:error, {:invalid_adapter_response, :fetch_candidate_issues}} = Tracker.fetch_candidate_issues()
    end
  end

  describe "fetch_issues_by_states/1" do
    test "delegates to adapter with normalized states" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, MockAdapter)
      assert {:ok, [:issue2]} = Tracker.fetch_issues_by_states([" state1 ", "", "state2"])
      assert_received {:mock_fetch_issues_by_states, ["state1", "state2"]}
    end

    test "returns validation error for invalid states list" do
      assert {:error, :invalid_states} = Tracker.fetch_issues_by_states("not a list")
      assert {:ok, []} = Tracker.fetch_issues_by_states([123])
    end

    test "returns error when adapter fails" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, ErrorAdapter)
      assert {:error, :fetch_failed} = Tracker.fetch_issues_by_states(["state1"])
    end

    test "normalizes invalid adapter response" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, InvalidAdapter)
      assert {:error, {:invalid_adapter_response, :fetch_issues_by_states}} = Tracker.fetch_issues_by_states(["state1"])
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "delegates to adapter with normalized ids" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, MockAdapter)
      assert {:ok, [:state1]} = Tracker.fetch_issue_states_by_ids([" id1 ", "", "id2"])
      assert_received {:mock_fetch_issue_states_by_ids, ["id1", "id2"]}
    end

    test "returns validation error for invalid ids list" do
      assert {:error, :invalid_issue_ids} = Tracker.fetch_issue_states_by_ids("not a list")
      assert {:ok, []} = Tracker.fetch_issue_states_by_ids([123])
    end

    test "returns error when adapter fails" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, ErrorAdapter)
      assert {:error, :fetch_failed} = Tracker.fetch_issue_states_by_ids(["id1"])
    end

    test "normalizes invalid adapter response" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, InvalidAdapter)
      assert {:error, {:invalid_adapter_response, :fetch_issue_states_by_ids}} = Tracker.fetch_issue_states_by_ids(["id1"])
    end
  end

  describe "create_comment/2" do
    test "delegates to adapter with normalized inputs" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, MockAdapter)
      assert :ok = Tracker.create_comment(" id1 ", " body ")
      assert_received {:mock_create_comment, "id1", "body"}
    end

    test "returns validation error for invalid issue id" do
      assert {:error, :invalid_issue_id} = Tracker.create_comment("", "body")
      assert {:error, :invalid_issue_id} = Tracker.create_comment("   ", "body")
      assert {:error, :invalid_issue_id} = Tracker.create_comment(123, "body")
    end

    test "returns validation error for invalid body" do
      assert {:error, :invalid_comment_body} = Tracker.create_comment("id1", "")
      assert {:error, :invalid_comment_body} = Tracker.create_comment("id1", "   ")
      assert {:error, :invalid_comment_body} = Tracker.create_comment("id1", 123)
    end

    test "returns error when adapter fails" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, ErrorAdapter)
      assert {:error, :create_failed} = Tracker.create_comment("id1", "body")
    end

    test "normalizes invalid adapter response" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, InvalidAdapter)
      assert {:error, {:invalid_adapter_response, :create_comment}} = Tracker.create_comment("id1", "body")
    end
  end

  describe "update_issue_state/2" do
    test "delegates to adapter with normalized inputs" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, MockAdapter)
      assert :ok = Tracker.update_issue_state(" id1 ", " state1 ")
      assert_received {:mock_update_issue_state, "id1", "state1"}
    end

    test "returns validation error for invalid issue id" do
      assert {:error, :invalid_issue_id} = Tracker.update_issue_state("", "state")
      assert {:error, :invalid_issue_id} = Tracker.update_issue_state("   ", "state")
      assert {:error, :invalid_issue_id} = Tracker.update_issue_state(123, "state")
    end

    test "returns validation error for invalid state name" do
      assert {:error, :invalid_state_name} = Tracker.update_issue_state("id1", "")
      assert {:error, :invalid_state_name} = Tracker.update_issue_state("id1", "   ")
      assert {:error, :invalid_state_name} = Tracker.update_issue_state("id1", 123)
    end

    test "returns error when adapter fails" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, ErrorAdapter)
      assert {:error, :update_failed} = Tracker.update_issue_state("id1", "state")
    end

    test "normalizes invalid adapter response" do
      Application.put_env(:symphony_elixir, :tracker_adapter_module, InvalidAdapter)
      assert {:error, {:invalid_adapter_response, :update_issue_state}} = Tracker.update_issue_state("id1", "state")
    end
  end
end
