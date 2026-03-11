defmodule SymphonyElixir.Tracker.MemoryTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.Linear.Issue
  alias SymphonyElixir.Tracker.Memory

  setup do
    # Save the original env to restore it after the test
    original_issues = Application.get_env(:symphony_elixir, :memory_tracker_issues)
    original_recipient = Application.get_env(:symphony_elixir, :memory_tracker_recipient)

    on_exit(fn ->
      if original_issues do
        Application.put_env(:symphony_elixir, :memory_tracker_issues, original_issues)
      else
        Application.delete_env(:symphony_elixir, :memory_tracker_issues)
      end

      if original_recipient do
        Application.put_env(:symphony_elixir, :memory_tracker_recipient, original_recipient)
      else
        Application.delete_env(:symphony_elixir, :memory_tracker_recipient)
      end
    end)

    :ok
  end

  describe "fetch_candidate_issues/0" do
    test "returns empty list when no issues are configured" do
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [])
      assert {:ok, []} = Memory.fetch_candidate_issues()
    end

    test "returns configured issues that are actual Issue structs" do
      issue1 = %Issue{id: "iss-1", title: "Task 1"}
      issue2 = %Issue{id: "iss-2", title: "Task 2"}

      # include a non-Issue struct to verify filtering
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [issue1, %{id: "iss-not-struct"}, issue2])

      assert {:ok, [^issue1, ^issue2]} = Memory.fetch_candidate_issues()
    end
  end

  describe "fetch_issues_by_states/1" do
    test "filters issues by normalized states" do
      issue_todo = %Issue{id: "1", state: "Todo"}
      issue_in_progress = %Issue{id: "2", state: "In Progress "}
      issue_done = %Issue{id: "3", state: "done"}

      Application.put_env(:symphony_elixir, :memory_tracker_issues, [
        issue_todo,
        issue_in_progress,
        issue_done
      ])

      assert {:ok, [^issue_todo]} = Memory.fetch_issues_by_states(["todo"])
      assert {:ok, [^issue_in_progress]} = Memory.fetch_issues_by_states([" in progress"])

      assert {:ok, [^issue_todo, ^issue_done]} = Memory.fetch_issues_by_states(["TODO", "Done"])

      assert {:ok, []} = Memory.fetch_issues_by_states(["nonexistent"])
    end

    test "handles nil states safely" do
      issue_nil_state = %Issue{id: "1", state: nil}
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [issue_nil_state])

      # nil states normalize to "" in the implementation, so they won't match "todo"
      assert {:ok, []} = Memory.fetch_issues_by_states(["todo"])
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "filters issues by matching ids" do
      issue1 = %Issue{id: "1", state: "Todo"}
      issue2 = %Issue{id: "2", state: "In Progress"}
      issue3 = %Issue{id: "3", state: "Done"}

      Application.put_env(:symphony_elixir, :memory_tracker_issues, [
        issue1,
        issue2,
        issue3
      ])

      assert {:ok, [^issue1]} = Memory.fetch_issue_states_by_ids(["1"])
      assert {:ok, [^issue2, ^issue3]} = Memory.fetch_issue_states_by_ids(["2", "3"])
      assert {:ok, []} = Memory.fetch_issue_states_by_ids(["99"])
    end
  end

  describe "create_comment/2" do
    test "sends event when recipient is a pid" do
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

      assert :ok = Memory.create_comment("iss-1", "Test comment")
      assert_receive {:memory_tracker_comment, "iss-1", "Test comment"}
    end

    test "does not crash when recipient is not configured" do
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)

      assert :ok = Memory.create_comment("iss-1", "Test comment")
      refute_receive {:memory_tracker_comment, _, _}
    end

    test "does not crash when recipient is not a pid" do
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, :not_a_pid)

      assert :ok = Memory.create_comment("iss-1", "Test comment")
      refute_receive {:memory_tracker_comment, _, _}
    end
  end

  describe "update_issue_state/2" do
    test "sends event when recipient is a pid" do
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

      assert :ok = Memory.update_issue_state("iss-1", "Done")
      assert_receive {:memory_tracker_state_update, "iss-1", "Done"}
    end

    test "does not crash when recipient is not configured" do
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)

      assert :ok = Memory.update_issue_state("iss-1", "Done")
      refute_receive {:memory_tracker_state_update, _, _}
    end
  end
end
