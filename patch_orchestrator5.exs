path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "  defp fetch_candidate_issues(active_states, terminal_states) do\n    active_states = active_state_set()\n    terminal_states = terminal_state_set()",
  "  defp fetch_candidate_issues(active_states, terminal_states) do"
)

File.write!(path, content)
