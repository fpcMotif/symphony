defmodule FixOrchestrator11 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 470: batch_dispatch_issues unused terminal_states
    content = String.replace(
      content,
      "defp batch_dispatch_issues(candidates, %State{} = state, terminal_states) do",
      "defp batch_dispatch_issues(candidates, %State{} = state) do"
    )
    content = String.replace(
      content,
      "batch_dispatch_issues(candidates, state, terminal_states)",
      "batch_dispatch_issues(candidates, state)"
    )

    # 695: revalidate_issue_for_dispatch unused terminal_states
    content = String.replace(
      content,
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, terminal_states)",
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, active_states, terminal_states)"
    )
    content = String.replace(
      content,
      "if retry_candidate_issue?(refreshed_issue, state.active_state_set, state.terminal_state_set) do",
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
    )

    # Update revalidate_issue_for_dispatch calls to pass active_states
    # 287
    content = String.replace(
      content,
      "case revalidate_issue_for_dispatch(issue, issue_fetcher, state.terminal_state_set) do",
      "case revalidate_issue_for_dispatch(issue, issue_fetcher, state.active_state_set, state.terminal_state_set) do"
    )
    # 625
    content = String.replace(
      content,
      "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.terminal_state_set) do",
      "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.active_state_set, state.terminal_state_set) do"
    )

    File.write!(path, content)
  end
end

FixOrchestrator11.run()
