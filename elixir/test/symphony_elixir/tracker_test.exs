defmodule SymphonyElixir.TrackerTest do
  use SymphonyElixir.TestSupport
  alias SymphonyElixir.Tracker
  alias SymphonyElixir.Workflow

  setup do
    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :tracker_adapter_module)
    end)

    :ok
  end

  describe "fetch_candidate_issues/0" do
    test "delegates to the configured adapter and normalizes the response" do
      # Configure a custom memory-like stub just for this test
      defmodule TrackerStub do
        def fetch_candidate_issues do
          {:ok, [%{id: "ISSUE-123", state: "Todo"}]}
        end
      end

      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "custom", tracker_adapter_module: "SymphonyElixir.TrackerTest.TrackerStub")

      assert {:ok, [%{id: "ISSUE-123", state: "Todo"}]} = Tracker.fetch_candidate_issues()
    end

    test "normalizes errors gracefully" do
      defmodule ErrorTrackerStub do
        def fetch_candidate_issues do
          {:error, :service_unavailable}
        end
      end

      write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "custom", tracker_adapter_module: "SymphonyElixir.TrackerTest.ErrorTrackerStub")

      assert {:error, :service_unavailable} = Tracker.fetch_candidate_issues()
    end
  end
end
