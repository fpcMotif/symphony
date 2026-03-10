path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "    active_states = active_state_set()\n    terminal_states = terminal_state_set()\n\n    issues\n    |> sort_issues_for_dispatch()",
  "    issues\n    |> sort_issues_for_dispatch()"
)

File.write!(path, content)
