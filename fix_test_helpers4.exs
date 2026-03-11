defmodule FixTestHelpers4 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # In reconcile_issue_states_for_test
    content = String.replace(
      content,
      "reconcile_running_issue_states(issues, state, state.active_state_set, state.terminal_state_set)",
      "reconcile_running_issue_states(issues, state, active_state_set(), terminal_state_set())"
    )

    File.write!(path, content)
  end
end

FixTestHelpers4.run()
