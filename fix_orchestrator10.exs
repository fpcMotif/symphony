defmodule FixOrchestrator10 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 801
    content = String.replace(
      content,
      "retry_candidate_issue?(issue, active_states, terminal_states) ->",
      "retry_candidate_issue?(issue, state.active_state_set, state.terminal_state_set) ->"
    )

    # 480: batch_dispatch_issues is passed state and terminal_states, it needs active_states
    content = String.replace(
      content,
      "defp batch_dispatch_issues(candidates, %State{} = state, terminal_states) do",
      "defp batch_dispatch_issues(candidates, %State{} = state, terminal_states) do"
    )
    # Inside batch_dispatch_issues:
    content = String.replace(
      content,
      "retry_candidate_issue?(refreshed_issue, active_states, terminal_states)",
      "retry_candidate_issue?(refreshed_issue, state.active_state_set, state.terminal_state_set)"
    )

    File.write!(path, content)
  end
end

FixOrchestrator10.run()
