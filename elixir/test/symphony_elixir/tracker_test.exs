defmodule SymphonyElixir.TrackerTest do
  use SymphonyElixir.TestSupport, async: false
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
      defmodule TrackerStub do
        def fetch_candidate_issues do
          {:ok, [%{id: "ISSUE-123", state: "Todo"}]}
        end
      end

      Application.put_env(:symphony_elixir, :tracker_adapter_module, TrackerStub)

      assert {:ok, [%{id: "ISSUE-123", state: "Todo"}]} = Tracker.fetch_candidate_issues()
    end

    test "normalizes errors gracefully" do
      defmodule ErrorTrackerStub do
        def fetch_candidate_issues do
          {:error, :service_unavailable}
        end
      end

      Application.put_env(:symphony_elixir, :tracker_adapter_module, ErrorTrackerStub)

      assert {:error, :service_unavailable} = Tracker.fetch_candidate_issues()
    end
  end
end
