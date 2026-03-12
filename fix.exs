content = File.read!("elixir/lib/symphony_elixir/orchestrator.ex")
old_code = """
  defp batch_dispatch_issues(candidates, %State{} = state, terminal_states) do
    candidate_ids = Enum.map(candidates, & &1.id)

    case Tracker.fetch_issue_states_by_ids(candidate_ids) do
      {:ok, refreshed_issues} ->
        refreshed_issues_map = Map.new(refreshed_issues, &{&1.id, &1})

        Enum.reduce(candidates, state, fn issue, state_acc ->
          case Map.fetch(refreshed_issues_map, issue.id) do
            {:ok, %Issue{} = refreshed_issue} ->
              if retry_candidate_issue?(refreshed_issue, terminal_states) do
                do_dispatch_issue(state_acc, refreshed_issue, nil)
              else
                Logger.info("Skipping stale dispatch after issue refresh: \#{issue_context(refreshed_issue)} state=\#{inspect(refreshed_issue.state)} blocked_by=\#{length(refreshed_issue.blocked_by)}")
                state_acc
              end

            :error ->
              Logger.info("Skipping dispatch; issue no longer active or visible: \#{issue_context(issue)}")
              state_acc
          end
        end)

      {:error, reason} ->
        Logger.warning("Skipping batch dispatch; issue refresh failed: \#{inspect(reason)}")
        state
    end
  end
"""
new_code = """
  defp batch_dispatch_issues(candidates, %State{} = state, terminal_states) do
    candidate_ids = Enum.map(candidates, & &1.id)

    case Tracker.fetch_issue_states_by_ids(candidate_ids) do
      {:ok, refreshed_issues} ->
        refreshed_issues_map = Map.new(refreshed_issues, &{&1.id, &1})

        Enum.reduce(candidates, state, fn issue, state_acc ->
          process_batched_issue(issue, state_acc, refreshed_issues_map, terminal_states)
        end)

      {:error, reason} ->
        Logger.warning("Skipping batch dispatch; issue refresh failed: \#{inspect(reason)}")
        state
    end
  end

  defp process_batched_issue(issue, state_acc, refreshed_issues_map, terminal_states) do
    case Map.fetch(refreshed_issues_map, issue.id) do
      {:ok, %Issue{} = refreshed_issue} ->
        if retry_candidate_issue?(refreshed_issue, terminal_states) do
          do_dispatch_issue(state_acc, refreshed_issue, nil)
        else
          Logger.info("Skipping stale dispatch after issue refresh: \#{issue_context(refreshed_issue)} state=\#{inspect(refreshed_issue.state)} blocked_by=\#{length(refreshed_issue.blocked_by)}")
          state_acc
        end

      :error ->
        Logger.info("Skipping dispatch; issue no longer active or visible: \#{issue_context(issue)}")
        state_acc
    end
  end
"""
new_content = String.replace(content, old_code, new_code)
File.write!("elixir/lib/symphony_elixir/orchestrator.ex", new_content)
