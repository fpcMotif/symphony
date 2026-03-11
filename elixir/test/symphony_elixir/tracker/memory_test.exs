defmodule SymphonyElixir.Tracker.MemoryTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.Linear.Issue
  alias SymphonyElixir.Tracker.Memory

  setup do
    original_issues = Application.get_env(:symphony_elixir, :memory_tracker_issues)
    original_recipient = Application.get_env(:symphony_elixir, :memory_tracker_recipient)

    issues = [
      %Issue{id: "issue-1", state: "In Progress", title: "First issue"},
      %Issue{id: "issue-2", state: "todo", title: "Second issue"},
      %Issue{id: "issue-3", state: "  IN pRoGrEsS  ", title: "Third issue"},
      %{id: "not-an-issue-struct", state: "todo"}
    ]

    Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)
    Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

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
    test "returns only configured %Issue{} structs" do
      assert {:ok, results} = Memory.fetch_candidate_issues()
      assert length(results) == 3
      assert [%Issue{id: "issue-1"}, %Issue{id: "issue-2"}, %Issue{id: "issue-3"}] = results
    end

    test "returns empty list if no issues configured" do
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [])
      assert {:ok, []} = Memory.fetch_candidate_issues()
    end
  end

  describe "fetch_issues_by_states/1" do
    test "filters issues by normalized states (case-insensitive and trimmed)" do
      assert {:ok, results} = Memory.fetch_issues_by_states(["in progress"])
      assert length(results) == 2
      assert [%Issue{id: "issue-1"}, %Issue{id: "issue-3"}] = results
    end

    test "returns empty list if no states match" do
      assert {:ok, []} = Memory.fetch_issues_by_states(["done", "closed"])
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "filters issues by exact ID matches" do
      assert {:ok, results} = Memory.fetch_issue_states_by_ids(["issue-2", "issue-3", "nonexistent"])
      assert length(results) == 2
      assert [%Issue{id: "issue-2"}, %Issue{id: "issue-3"}] = results
    end

    test "returns empty list if no IDs match" do
      assert {:ok, []} = Memory.fetch_issue_states_by_ids(["nonexistent"])
    end
  end

  describe "create_comment/2" do
    test "sends event to configured recipient" do
      assert :ok = Memory.create_comment("issue-1", "Test comment body")
      assert_receive {:memory_tracker_comment, "issue-1", "Test comment body"}
    end

    test "does not crash if recipient is not a pid" do
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, nil)
      assert :ok = Memory.create_comment("issue-1", "Test comment body")
      refute_receive {:memory_tracker_comment, _, _}
    end
  end

  describe "update_issue_state/2" do
    test "sends event to configured recipient" do
      assert :ok = Memory.update_issue_state("issue-2", "done")
      assert_receive {:memory_tracker_state_update, "issue-2", "done"}
    end

    test "does not crash if recipient is not a pid" do
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, :not_a_pid)
      assert :ok = Memory.update_issue_state("issue-2", "done")
      refute_receive {:memory_tracker_state_update, _, _}
    end
  end
end
