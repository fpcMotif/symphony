defmodule FixOrchestrator12 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 480: batch_dispatch_issues
    content = String.replace(
      content,
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do",
      "if retry_candidate_issue?(refreshed_issue, state.active_state_set, state.terminal_state_set) do"
    )

    File.write!(path, content)
  end
end

FixOrchestrator12.run()
