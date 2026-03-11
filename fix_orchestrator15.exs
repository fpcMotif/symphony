defmodule FixOrchestrator15 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Change line 699 back to active_states, terminal_states
    content = String.replace(
      content,
      "if retry_candidate_issue?(refreshed_issue, state.active_state_set, state.terminal_state_set) do",
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
    )

    # But wait, batch_dispatch_issues ALSO had this replacement. I need to be careful not to replace it in batch_dispatch_issues if I only meant to replace in revalidate_issue_for_dispatch.
    # Actually, batch_dispatch_issues uses state_acc, not state inside Enum.reduce!
    # Let's fix that too.
    File.write!(path, content)
  end
end

FixOrchestrator15.run()
