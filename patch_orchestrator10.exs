path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, terminal_states)",
  "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, terminal_states, active_states)"
)

content = String.replace(
  content,
  "defp revalidate_issue_for_dispatch(issue, _issue_fetcher, _terminal_states), do: {:ok, issue}",
  "defp revalidate_issue_for_dispatch(issue, _issue_fetcher, _terminal_states, _active_states), do: {:ok, issue}"
)

File.write!(path, content)
