path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "defp revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states, active_states) do\n    case issue_fetcher.([issue.id]) do\n      {:ok, [%Issue{} = refreshed_issue | _]} ->\n        if terminal_states != nil and\n             terminal_issue_state?(refreshed_issue.state, terminal_states) do\n          Logger.debug(\"Issue state is terminal: issue_id=#{issue.id} issue_identifier=#{issue.identifier} state=#{issue.state}; removing associated workspace\")\n          cleanup_issue_workspace(issue.identifier)\n          {:skip, :missing}\n        else\n          if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do",
  "defp revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_states, active_states) do\n    case issue_fetcher.([issue.id]) do\n      {:ok, [%Issue{} = refreshed_issue | _]} ->\n        if terminal_states != nil and\n             terminal_issue_state?(refreshed_issue.state, terminal_states) do\n          Logger.debug(\"Issue state is terminal: issue_id=#{issue.id} issue_identifier=#{issue.identifier} state=#{issue.state}; removing associated workspace\")\n          cleanup_issue_workspace(issue.identifier)\n          {:skip, :missing}\n        else\n          if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
)

# the previous regex replace might have failed. Let's look at the function signature.
File.write!(path, content)
