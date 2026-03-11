defmodule FixOrchestrator8 do
  def run do
    path = "elixir/lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Fix 801: handle_retry_issue_lookup
    # It has access to state.
    content = String.replace(
      content,
      "retry_candidate_issue?(issue, active_states, terminal_states)",
      "retry_candidate_issue?(issue, state.active_state_set, state.terminal_state_set)"
    )

    # Fix 480 & 464 & 470: batch_dispatch_issues
    # 470: defp batch_dispatch_issues(candidates, %State{} = state, terminal_states) do
    # 464: batch_dispatch_issues(candidates, state, terminal_states)
    content = String.replace(
      content,
      "batch_dispatch_issues(candidates, state, terminal_states)",
      "batch_dispatch_issues(candidates, state, active_states, terminal_states)"
    )
    content = String.replace(
      content,
      "defp batch_dispatch_issues(candidates, %State{} = state, terminal_states) do",
      "defp batch_dispatch_issues(candidates, %State{} = state, active_states, terminal_states) do"
    )

    # Fix 699: revalidate_issue_for_dispatch
    # This also needs active_states in its signature.
    # Where is it defined?
    content = String.replace(
      content,
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, terminal_states)",
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, active_states, terminal_states)"
    )

    File.write!(path, content)
  end
end

FixOrchestrator8.run()
