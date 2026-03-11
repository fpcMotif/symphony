defmodule FixOrchestrator17 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # In revalidate_issue_for_dispatch, we need active_states, terminal_states
    content = String.replace(
      content,
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, active_states, terminal_states)\n       when is_binary(issue_id) and is_function(issue_fetcher, 1) do\n    case issue_fetcher.([issue_id]) do\n      {:ok, [%Issue{} = refreshed_issue | _]} ->\n        if retry_candidate_issue?(refreshed_issue, state_acc.active_state_set, state_acc.terminal_state_set) do",
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, active_states, terminal_states)\n       when is_binary(issue_id) and is_function(issue_fetcher, 1) do\n    case issue_fetcher.([issue_id]) do\n      {:ok, [%Issue{} = refreshed_issue | _]} ->\n        if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
    )

    File.write!(path, content)
  end
end

FixOrchestrator17.run()
