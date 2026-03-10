path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher, terminal_states \\\\ terminal_state_set())",
  "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher, terminal_states \\\\ terminal_state_set(), active_states \\\\ active_state_set())"
)

content = String.replace(
  content,
  "revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states)",
  "revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states, active_states)"
)

content = String.replace(
  content,
  "defp revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states) do",
  "defp revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states, active_states) do"
)

content = String.replace(
  content,
  "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.terminal_states) do",
  "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.terminal_states, state.active_states) do"
)

content = String.replace(
  content,
  "if retry_candidate_issue?(refreshed_issue, active_state_set(), terminal_states) do",
  "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
)

content = String.replace(
  content,
  "  defp fetch_candidate_issues(active_states, terminal_states) do\n    active_states = active_state_set()\n    terminal_states = terminal_state_set()",
  "  defp fetch_candidate_issues(active_states, terminal_states) do"
)

content = String.replace(
  content,
  "  defp handle_retry_issue_lookup(%Issue{} = issue, state, issue_id, attempt, metadata) do\n    terminal_states = terminal_state_set()",
  "  defp handle_retry_issue_lookup(%Issue{} = issue, state, issue_id, attempt, metadata) do\n    terminal_states = state.terminal_states"
)

File.write!(path, content)
