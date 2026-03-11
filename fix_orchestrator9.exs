defmodule FixOrchestrator9 do
  def run do
    path = "elixir/lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 801
    content = String.replace(
      content,
      "retry_candidate_issue?(issue, active_states, terminal_states) ->",
      "retry_candidate_issue?(issue, state.active_state_set, state.terminal_state_set) ->"
    )

    # 699
    content = String.replace(
      content,
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do",
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
    )

    # Re-read 695:705
    content = String.replace(
      content,
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, terminal_states)",
      "defp revalidate_issue_for_dispatch(%Issue{id: issue_id}, issue_fetcher, active_states, terminal_states)"
    )

    # 480
    content = String.replace(
      content,
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do",
      "if retry_candidate_issue?(refreshed_issue, active_states, terminal_states) do"
    )

    File.write!(path, content)
  end
end
