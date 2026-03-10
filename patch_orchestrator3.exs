path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "retry_candidate_issue?(issue, active_state_set(), terminal_states)",
  "retry_candidate_issue?(issue, state.active_states, terminal_states)"
)

# wait, for revalidate_issue_for_dispatch: it might not have state.
content = String.replace(
  content,
  "if retry_candidate_issue?(refreshed_issue, state.active_states, terminal_states) do",
  "if retry_candidate_issue?(refreshed_issue, active_state_set(), terminal_states) do"
)


File.write!(path, content)
