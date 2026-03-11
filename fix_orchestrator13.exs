defmodule FixOrchestrator13 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 695: revalidate_issue_for_dispatch
    # Change the body back to use active_states and terminal_states
    content = String.replace(
      content,
      "if retry_candidate_issue?(refreshed_issue, state.active_state_set, state.terminal_state_set) do",
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
    )

    File.write!(path, content)
  end
end

FixOrchestrator13.run()
