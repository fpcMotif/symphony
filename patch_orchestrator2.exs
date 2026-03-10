path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "if retry_candidate_issue?(refreshed_issue, terminal_states) do",
  "if retry_candidate_issue?(refreshed_issue, active_state_set(), terminal_states) do"
)

content = String.replace(
  content,
  "retry_candidate_issue?(issue, terminal_states) ->",
  "retry_candidate_issue?(issue, active_state_set(), terminal_states) ->"
)

# wait, we can pass state to handle_retry_issue_lookup and revalidate_issue_for_dispatch, but they don't have access to active_states easily.
# actually, handle_retry_issue_lookup has `state`, so `state.active_states`.
# revalidate_issue_for_dispatch might not have state. Let's look.
File.write!(path, content)
