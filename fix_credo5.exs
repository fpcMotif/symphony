defmodule FixCredo5 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Insert it right before the last end
    last_end = String.replace_suffix(content, "\nend\n", "
  defp dispatch_refreshed_issue(issue, state_acc, refreshed_issues_map) do
    case Map.fetch(refreshed_issues_map, issue.id) do
      {:ok, %Issue{} = refreshed_issue} ->
        if retry_candidate_issue?(refreshed_issue, state_acc.active_state_set, state_acc.terminal_state_set) do
          do_dispatch_issue(state_acc, refreshed_issue, nil)
        else
          Logger.info(\"Skipping stale dispatch after issue refresh: \#{issue_context(refreshed_issue)} state=\#{inspect(refreshed_issue.state)} blocked_by=\#{length(refreshed_issue.blocked_by)}\")
          state_acc
        end

      :error ->
        Logger.info(\"Skipping dispatch; issue no longer active or visible: \#{issue_context(issue)}\")
        state_acc
    end
  end\nend\n")

    File.write!(path, last_end)
  end
end

FixCredo5.run()
