defmodule SymphonyElixir.OrchestratorTrackerApiTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Orchestrator

  test "create_comment/3 writes a comment via the tracker API" do
    write_workflow_file!(SymphonyElixir.Workflow.workflow_file_path(),
      tracker_kind: "memory"
    )

    Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

    assert :ok = Orchestrator.create_comment(SymphonyElixir.Orchestrator, "issue-123", "Test comment")

    assert_receive {:memory_tracker_comment, "issue-123", "Test comment"}
  end

  test "update_issue_state/3 updates an issue state via the tracker API" do
    write_workflow_file!(SymphonyElixir.Workflow.workflow_file_path(),
      tracker_kind: "memory"
    )

    Application.put_env(:symphony_elixir, :memory_tracker_recipient, self())

    assert :ok = Orchestrator.update_issue_state(SymphonyElixir.Orchestrator, "issue-123", "Done")

    assert_receive {:memory_tracker_state_update, "issue-123", "Done"}
  end
end
