path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "            active_state_set(),\n            terminal_state_set()",
  "            state.active_states,\n            state.terminal_states"
)

content = String.replace(
  content,
  "reconcile_running_issue_states(issues, state, active_state_set(), terminal_state_set())",
  "reconcile_running_issue_states(issues, state, state.active_states, state.terminal_states)"
)

content = String.replace(
  content,
  "should_dispatch_issue?(issue, state, active_state_set(), terminal_state_set())",
  "should_dispatch_issue?(issue, state, state.active_states, state.terminal_states)"
)

content = String.replace(
  content,
  "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher)\n      when is_function(issue_fetcher, 1) do\n    revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_state_set())\n  end",
  "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher, terminal_states \\\\ terminal_state_set())\n      when is_function(issue_fetcher, 1) do\n    revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states)\n  end"
)

content = String.replace(
  content,
  "defp revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states \\\\ terminal_state_set()) do",
  "defp revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states) do"
)

content = String.replace(
  content,
  "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, terminal_state_set()) do",
  "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.terminal_states) do"
)

content = String.replace(
  content,
  "if retry_candidate_issue?(issue, terminal_state_set()) and",
  "if retry_candidate_issue?(issue, state.active_states, state.terminal_states) and"
)

content = String.replace(
  content,
  "defp retry_candidate_issue?(%Issue{} = issue, terminal_states) do\n    candidate_issue?(issue, active_state_set(), terminal_states) and\n      !todo_issue_blocked_by_non_terminal?(issue, terminal_states)\n  end",
  "defp retry_candidate_issue?(%Issue{} = issue, active_states, terminal_states) do\n    candidate_issue?(issue, active_states, terminal_states) and\n      !todo_issue_blocked_by_non_terminal?(issue, terminal_states)\n  end"
)

content = String.replace(
  content,
  "  defp fetch_candidate_issues do\n    active_states = active_state_set()\n    terminal_states = terminal_state_set()",
  "  defp fetch_candidate_issues(active_states, terminal_states) do"
)

content = String.replace(
  content,
  "  defp maybe_dispatch(%State{} = state) do\n    if available_slots(state) > 0 do\n      Logger.debug(\"Polling Linear for missing/available issues\")\n\n      case fetch_candidate_issues() do",
  "  defp maybe_dispatch(%State{} = state) do\n    if available_slots(state) > 0 do\n      Logger.debug(\"Polling Linear for missing/available issues\")\n\n      case fetch_candidate_issues(state.active_states, state.terminal_states) do"
)

content = String.replace(
  content,
  "  defp find_orphaned_issues(issues, running) do\n    terminal_states = terminal_state_set()",
  "  defp find_orphaned_issues(issues, running, terminal_states) do"
)

content = String.replace(
  content,
  "orphaned = find_orphaned_issues(issues, state.running)",
  "orphaned = find_orphaned_issues(issues, state.running, terminal_states)"
)


File.write!(path, content)
