defmodule FixCredo2 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 625 fix
    content = String.replace(
      content,
      "case revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.active_state_set, state.terminal_state_set) do",
      "case revalidate_issue_for_dispatch(\n           issue,\n           &Tracker.fetch_issue_states_by_ids/1,\n           state.active_state_set,\n           state.terminal_state_set\n         ) do"
    )

    File.write!(path, content)
  end
end

FixCredo2.run()
