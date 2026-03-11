defmodule FixCredo3 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Move Enum.reduce logic to a private helper function to reduce nesting
    search = "Enum.reduce(candidates, state, fn issue, state_acc ->\n          case Map.fetch(refreshed_issues_map, issue.id) do\n            {:ok, %Issue{} = refreshed_issue} ->\n              if retry_candidate_issue?(refreshed_issue, state_acc.active_state_set, state_acc.terminal_state_set) do\n                do_dispatch_issue(state_acc, refreshed_issue, nil)\n              else\n                Logger.info(\"Skipping stale dispatch after issue refresh: \#{issue_context(refreshed_issue)} state=\#{inspect(refreshed_issue.state)} blocked_by=\#{length(refreshed_issue.blocked_by)}\")\n                state_acc\n              end\n\n            :error ->\n              Logger.info(\"Skipping dispatch; issue no longer active or visible: \#{issue_context(issue)}\")\n              state_acc\n          end\n        end)"

    replace = "Enum.reduce(candidates, state, &dispatch_refreshed_issue(&1, &2, refreshed_issues_map))"

    helper_fn = "
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
  end
"

    # Insert helper before handle_dispatch_failure or somewhere appropriate
    content = String.replace(content, search, replace)
    content = String.replace(content, "defp handle_dispatch_failure", helper_fn <> "\n  defp handle_dispatch_failure")

    File.write!(path, content)
  end
end

FixCredo3.run()
