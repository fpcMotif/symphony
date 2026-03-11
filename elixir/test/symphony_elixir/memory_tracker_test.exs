defmodule SymphonyElixir.Tracker.MemoryTest do
  use ExUnit.Case, async: false

  alias SymphonyElixir.Linear.Issue
  alias SymphonyElixir.Tracker.Memory

  setup do
    on_exit(fn ->
      Application.delete_env(:symphony_elixir, :memory_tracker_issues)
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)
    end)

    :ok
  end

  describe "fetch_candidate_issues/0" do
    test "returns empty list when no issues configured" do
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [])
      assert {:ok, []} = Memory.fetch_candidate_issues()
    end

    test "returns configured issues" do
      issues = [
        %Issue{id: "1", identifier: "MT-1", title: "Test", state: "Todo", labels: []}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)
      assert {:ok, ^issues} = Memory.fetch_candidate_issues()
    end

    test "filters out non-Issue entries from configuration" do
      Application.put_env(:symphony_elixir, :memory_tracker_issues, [
        %Issue{id: "1", identifier: "MT-1", title: "Valid", state: "Todo", labels: []},
        "not an issue",
        %{id: "2", title: "raw map"},
        nil,
        42
      ])

      {:ok, results} = Memory.fetch_candidate_issues()
      assert length(results) == 1
      assert hd(results).id == "1"
    end

    test "returns empty list when config key is absent" do
      Application.delete_env(:symphony_elixir, :memory_tracker_issues)
      assert {:ok, []} = Memory.fetch_candidate_issues()
    end
  end

  describe "fetch_issues_by_states/1" do
    setup do
      issues = [
        %Issue{id: "1", identifier: "MT-1", title: "Open", state: "Todo", labels: []},
        %Issue{id: "2", identifier: "MT-2", title: "Active", state: "In Progress", labels: []},
        %Issue{id: "3", identifier: "MT-3", title: "Closed", state: "Done", labels: []}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)
      %{issues: issues}
    end

    test "filters by matching state (case-insensitive)" do
      {:ok, results} = Memory.fetch_issues_by_states(["todo"])
      assert length(results) == 1
      assert hd(results).id == "1"
    end

    test "handles mixed-case state names" do
      {:ok, results} = Memory.fetch_issues_by_states(["TODO", "in progress"])
      assert length(results) == 2
    end

    test "trims whitespace from state names" do
      {:ok, results} = Memory.fetch_issues_by_states(["  Todo  ", "  In Progress  "])
      assert length(results) == 2
    end

    test "returns empty list when no states match" do
      {:ok, results} = Memory.fetch_issues_by_states(["Nonexistent"])
      assert results == []
    end

    test "handles nil state gracefully" do
      {:ok, results} = Memory.fetch_issues_by_states([nil, "Todo"])
      assert length(results) == 1
    end
  end

  describe "fetch_issue_states_by_ids/1" do
    setup do
      issues = [
        %Issue{id: "1", identifier: "MT-1", title: "Open", state: "Todo", labels: []},
        %Issue{id: "2", identifier: "MT-2", title: "Active", state: "In Progress", labels: []}
      ]

      Application.put_env(:symphony_elixir, :memory_tracker_issues, issues)
      :ok
    end

    test "returns matching issues by ID" do
      {:ok, results} = Memory.fetch_issue_states_by_ids(["1"])
      assert length(results) == 1
      assert hd(results).id == "1"
    end

    test "returns empty list for non-existent IDs" do
      {:ok, results} = Memory.fetch_issue_states_by_ids(["nonexistent"])
      assert results == []
    end

    test "returns multiple matching issues" do
      {:ok, results} = Memory.fetch_issue_states_by_ids(["1", "2"])
      assert length(results) == 2
    end

    test "handles empty ID list" do
      {:ok, results} = Memory.fetch_issue_states_by_ids([])
      assert results == []
    end
  end

  describe "create_comment/2" do
    test "sends message to configured recipient" do
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

      assert :ok = Memory.create_comment("issue-1", "Hello comment")
      assert_receive {:memory_tracker_comment, "issue-1", "Hello comment"}
    end

    test "succeeds silently when no recipient is configured" do
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)
      assert :ok = Memory.create_comment("issue-1", "No recipient")
      refute_receive {:memory_tracker_comment, _, _}
    end
  end

  describe "update_issue_state/2" do
    test "sends message to configured recipient" do
      Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

      assert :ok = Memory.update_issue_state("issue-1", "Done")
      assert_receive {:memory_tracker_state_update, "issue-1", "Done"}
    end

    test "succeeds silently when no recipient is configured" do
      Application.delete_env(:symphony_elixir, :memory_tracker_recipient)
      assert :ok = Memory.update_issue_state("issue-1", "Done")
      refute_receive {:memory_tracker_state_update, _, _}
    end
  end
end
