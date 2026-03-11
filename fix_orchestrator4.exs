defmodule FixOrchestrator4 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Revert init/1 and refresh_runtime_config/1 to use the function call instead of state.active_state_set
    content = String.replace(
      content,
      "      active_state_set: state.active_state_set,\n      terminal_state_set: state.terminal_state_set",
      "      active_state_set: active_state_set(),\n      terminal_state_set: terminal_state_set()"
    )

    # 1. 844: acc_state is undefined, but what is it? Let's check handle_issue_fetch_results
    # It seems in handle_issue_fetch_results, it's not acc_state, or maybe I replaced it incorrectly.
    content = String.replace(
      content,
      "if retry_candidate_issue?(issue, acc_state.active_state_set, acc_state.terminal_state_set) and",
      "if retry_candidate_issue?(issue, state.active_state_set, state.terminal_state_set) and"
    )

    # 2. 287: revalidate_issue_for_dispatch_for_test
    content = String.replace(
      content,
      "revalidate_issue_for_dispatch(issue, issue_fetcher, state.terminal_state_set)",
      "revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_state_set())"
    )

    File.write!(path, content)
  end
end

FixOrchestrator4.run()
