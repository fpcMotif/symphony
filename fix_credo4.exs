defmodule FixCredo4 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Search for defp handle_dispatch_failure, the replacement must have failed.
    # Ah, I replaced "defp handle_dispatch_failure" but let's just append it.

    # Check if the function dispatch_refreshed_issue was added
    has_func = String.contains?(content, "defp dispatch_refreshed_issue")
    IO.puts("Has function: \#{has_func}")

    if not has_func do
      # Append to the bottom of the file before `end`
      parts = String.split(content, "defp handle_dispatch_failure")
      if length(parts) > 1 do
        # Insert it right before the first handle_dispatch_failure
        [head | tail] = parts
        helper = "
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
        content = head <> helper <> "defp handle_dispatch_failure" <> Enum.join(tail, "defp handle_dispatch_failure")
        File.write!(path, content)
      end
    end
  end
end

FixCredo4.run()
