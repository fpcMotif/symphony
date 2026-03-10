path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher, terminal_states \\\\ terminal_state_set(), active_states \\\\ active_state_set())",
  "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher, terminal_states \\\\ terminal_state_set(), active_states \\\\ active_state_set())"
)

# wait actually we don't need to change revalidate_issue_for_dispatch_for_test defaults since it's just for tests and it makes sense to use the function directly.
