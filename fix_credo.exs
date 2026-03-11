defmodule FixCredo do
  def run do
    path = "elixir/lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Line 625: Line is too long
    # case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.active_state_set, state.terminal_state_set) do
    content = String.replace(
      content,
      "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.active_state_set, state.terminal_state_set) do",
      "case revalidate_issue_for_dispatch(\n           issue,\n           &Tracker.fetch_issue_states_by_ids/1,\n           state.active_state_set,\n           state.terminal_state_set\n         ) do"
    )

    File.write!(path, content)
  end
end

FixCredo.run()
