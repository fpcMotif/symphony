defmodule FixOrchestrator6 do
  def run do
    path = "elixir/lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Add active_states argument to revalidate_issue_for_dispatch
    content = String.replace(
      content,
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, terminal_states)",
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, active_states, terminal_states)"
    )

    # Wait, there are multiple definitions/calls of revalidate_issue_for_dispatch
    # Let's fix those
    # 287: poll_retry_continue
    content = String.replace(
      content,
      "case revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_state_set()) do",
      "case revalidate_issue_for_dispatch(issue, issue_fetcher, state.active_state_set, state.terminal_state_set) do"
    )

    # 625: dispatch_issue
    content = String.replace(
      content,
      "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.terminal_state_set) do",
      "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.active_state_set, state.terminal_state_set) do"
    )

    # The one inside tests might be revalidate_issue_for_dispatch_for_test
    # Let's check revalidate_issue_for_dispatch calls globally
    File.write!(path, content)
  end
end

FixOrchestrator6.run()
