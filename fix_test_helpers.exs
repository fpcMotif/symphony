defmodule FixTestHelpers do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # In should_dispatch_issue_for_test
    # 279: should_dispatch_issue?(issue, state, state.active_state_set, state.terminal_state_set)
    # The tests pass a %State{} without correctly initializing these fields because they might be bypassing init.
    # We should use active_state_set() and terminal_state_set() in tests if the state lacks it.
    # But wait, these functions are private. Let's make sure the helpers use the current config.
    content = String.replace(
      content,
      "def should_dispatch_issue_for_test(%Issue{} = issue, %State{} = state) do\n    should_dispatch_issue?(issue, state, state.active_state_set, state.terminal_state_set)",
      "def should_dispatch_issue_for_test(%Issue{} = issue, %State{} = state) do\n    should_dispatch_issue?(issue, state, active_state_set(), terminal_state_set())"
    )

    # In revalidate_issue_for_dispatch_for_test
    content = String.replace(
      content,
      "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher)\n      when is_function(issue_fetcher, 1) do\n    revalidate_issue_for_dispatch(issue, issue_fetcher, state.active_state_set, state.terminal_state_set)",
      "def revalidate_issue_for_dispatch_for_test(%Issue{} = issue, issue_fetcher)\n      when is_function(issue_fetcher, 1) do\n    revalidate_issue_for_dispatch(issue, issue_fetcher, active_state_set(), terminal_state_set())"
    )

    File.write!(path, content)
  end
end

FixTestHelpers.run()
