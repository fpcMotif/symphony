defmodule SymphonyElixir.ConfigTest do
  use SymphonyElixir.TestSupport

  test "resolve env-backed secrets and normalize blank values" do
    original_api_key = System.get_env("LINEAR_API_KEY")
    original_assignee = System.get_env("LINEAR_ASSIGNEE")

    on_exit(fn ->
      restore_env("LINEAR_API_KEY", original_api_key)
      restore_env("LINEAR_ASSIGNEE", original_assignee)
    end)

    System.put_env("LINEAR_API_KEY", "env-token")
    System.put_env("LINEAR_ASSIGNEE", "")

    write_workflow_file!(Workflow.workflow_file_path(),
      tracker_api_token: "$LINEAR_API_KEY",
      tracker_assignee: "$LINEAR_ASSIGNEE"
    )

    assert Config.linear_api_token() == "env-token"
    assert Config.linear_assignee() == nil
  end

  test "codex runtime settings return a validation error for unsupported values" do
    write_workflow_file!(Workflow.workflow_file_path(), codex_approval_policy: ["reject"])

    assert {:error, {:invalid_codex_approval_policy, ["reject"]}} = Config.codex_runtime_settings()
    assert Config.codex_approval_policy() == %{"reject" => %{
             "mcp_elicitations" => true,
             "rules" => true,
             "sandbox_approval" => true
           }}
  end

  test "max_concurrent_agents_for_state normalizes state names and falls back" do
    write_workflow_file!(Workflow.workflow_file_path(),
      max_concurrent_agents: 9,
      max_concurrent_agents_by_state: %{"in progress" => 2, "todo" => 4}
    )

    assert Config.max_concurrent_agents_for_state("  In Progress  ") == 2
    assert Config.max_concurrent_agents_for_state("TODO") == 4
    assert Config.max_concurrent_agents_for_state("Blocked") == 9
    assert Config.max_concurrent_agents_for_state(:todo) == 9
  end

  test "validate! rejects unsupported tracker kinds" do
    write_workflow_file!(Workflow.workflow_file_path(), tracker_kind: "jira")

    assert {:error, {:unsupported_tracker_kind, "jira"}} = Config.validate!()
  end
end
