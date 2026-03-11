defmodule FixOrchestrator16 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # In batch_dispatch_issues, use state_acc.active_state_set and state_acc.terminal_state_set
    # Right now it has active_states and terminal_states
    content = String.replace(
      content,
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do",
      "if retry_candidate_issue?(refreshed_issue, state_acc.active_state_set, state_acc.terminal_state_set) do"
    )

    # But wait, we also replaced revalidate_issue_for_dispatch at line 699, which SHOULD use active_states and terminal_states
    # Let's fix line 699 specifically
    # Re-read 695:705
    File.write!(path, content)
  end
end

FixOrchestrator16.run()
