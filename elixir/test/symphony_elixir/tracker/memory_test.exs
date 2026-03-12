defmodule SymphonyElixir.Tracker.MemoryAdapterTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Tracker.Memory

  setup do
    Application.put_env(:symphony_elixir, :memory_tracker_issues, [])
    Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :memory_tracker_issues)
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)
    end)

    :ok
  end

  describe "fetch_candidate_issues/0" do
    test "returns all configured issues" do
      issues = [
        %Issue{id: "m1", identifier: "M-1", title: "First", state: "Todo"},
        %Issue{id: "m2", identifier: "M-2", title: "Second", state: "In Progress"}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      assert {:ok, result} = Memory.fetch_candidate_issues()
      assert length(result) == 2
      assert Enum.map(result, & &1.id) == ["m1", "m2"]
    end

    test "returns empty list when no issues configured" do
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [])
      assert {:ok, []} = Memory.fetch_candidate_issues()
    end

    test "filters out non-Issue entries" do
      entries = [
        %Issue{id: "m3", identifier: "M-3", title: "Valid", state: "Todo"},
        "not an issue",
        %{id: "m4"},
        42
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, entries)

      assert {:ok, result} = Memory.fetch_candidate_issues()
      assert length(result) == 1
      assert hd(result).id == "m3"
    end
  end

  describe "fetch_issues_by_states/1" do
    test "filters issues by normalized state name (case-insensitive)" do
      issues = [
        %Issue{id: "m10", identifier: "M-10", title: "Todo issue", state: "Todo"},
        %Issue{id: "m11", identifier: "M-11", title: "In Progress issue", state: "In Progress"},
        %Issue{id: "m12", identifier: "M-12", title: "Done issue", state: "Done"}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      assert {:ok, result} = Memory.fetch_issues_by_states(["todo", "IN PROGRESS"])
      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert "m10" in ids
      assert "m11" in ids
    end

    test "returns empty list when no issues match" do
      issues = [
        %Issue{id: "m13", identifier: "M-13", title: "Todo", state: "Todo"}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      assert {:ok, []} = Memory.fetch_issues_by_states(["Done"])
    end

    test "handles empty state list" do
      issues = [%Issue{id: "m14", identifier: "M-14", title: "Test", state: "Todo"}]
      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      assert {:ok, []} = Memory.fetch_issues_by_states([])
    end

    test "handles whitespace in state names" do
      issues = [
        %Issue{id: "m15", identifier: "M-15", title: "Trimmed", state: "  Todo  "}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      assert {:ok, result} = Memory.fetch_issues_by_states(["Todo"])
      assert length(result) == 1
    end

    test "handles non-string elements in state list and non-string issue states" do
      issues = [
        %Issue{id: "m16", identifier: "M-16", title: "Invalid state type", state: nil},
        %Issue{id: "m17", identifier: "M-17", title: "Valid state", state: "Todo"}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      # Non-string states and arguments both normalize to an empty string ("")
      # so testing for 42 evaluates true for nil
      assert {:ok, result} = Memory.fetch_issues_by_states([42, "Todo"])
      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert "m16" in ids
      assert "m17" in ids

      # Exclude non-string arguments
      assert {:ok, result2} = Memory.fetch_issues_by_states(["Todo"])
      assert length(result2) == 1
      assert hd(result2).id == "m17"
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    test "filters issues by ID set" do
      issues = [
        %Issue{id: "m20", identifier: "M-20", title: "First", state: "Todo"},
        %Issue{id: "m21", identifier: "M-21", title: "Second", state: "In Progress"},
        %Issue{id: "m22", identifier: "M-22", title: "Third", state: "Done"}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      assert {:ok, result} = Memory.fetch_issue_states_by_ids(["m20", "m22"])
      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert "m20" in ids
      assert "m22" in ids
    end

    test "returns empty list when no IDs match" do
      issues = [%Issue{id: "m23", identifier: "M-23", title: "Test", state: "Todo"}]
      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)

      assert {:ok, []} = Memory.fetch_issue_states_by_ids(["nonexistent"])
    end

    test "handles empty ID list" do
      assert {:ok, []} = Memory.fetch_issue_states_by_ids([])
    end
  end

  describe "create_comment/2" do
    test "sends event to configured recipient" do
      assert :ok = Memory.create_comment("issue-c1", "Hello comment")
      assert_received {:memory_tracker_comment, "issue-c1", "Hello comment"}
    end

    test "does not crash when no recipient configured" do
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)
      assert :ok = Memory.create_comment("issue-c2", "No recipient")
      refute_received {:memory_tracker_comment, _, _}
    end
  end

  describe "update_issue_state/2" do
    test "sends event to configured recipient" do
      assert :ok = Memory.update_issue_state("issue-s1", "Done")
      assert_received {:memory_tracker_state_update, "issue-s1", "Done"}
    end

    test "does not crash when no recipient configured" do
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)
      assert :ok = Memory.update_issue_state("issue-s2", "Done")
      refute_received {:memory_tracker_state_update, _, _}
    end
  end
end
