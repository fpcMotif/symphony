path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "  defp choose_issues(issues, state) do\n    issues\n    |> sort_issues_for_dispatch()",
  "  defp choose_issues(issues, state) do\n    active_states = state.active_states\n    terminal_states = state.terminal_states\n\n    issues\n    |> sort_issues_for_dispatch()"
)

File.write!(path, content)
