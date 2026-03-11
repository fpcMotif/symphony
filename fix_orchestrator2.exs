defmodule FixOrchestrator2 do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 445: handle_cast
    content = String.replace(
      content,
      "      active_states = active_state_set()\n      terminal_states = terminal_state_set()",
      "      active_states = state.active_state_set\n      terminal_states = state.terminal_state_set"
    )

    # 254: handle_info
    content = String.replace(
      content,
      "Tracker.fetch_issues(\n              active_state_set(),\n              terminal_state_set()\n            )",
      "Tracker.fetch_issues(\n              state.active_state_set,\n              state.terminal_state_set\n            )"
    )

    # 287: poll_retry_continue
    content = String.replace(
      content,
      "case revalidate_issue_for_dispatch(issue, issue_fetcher, terminal_state_set()) do",
      "case revalidate_issue_for_dispatch(issue, issue_fetcher, state.terminal_state_set) do"
    )

    # 792: handle_terminal_running_issues_result
    content = String.replace(
      content,
      "terminal_states = terminal_state_set()",
      "terminal_states = state.terminal_state_set"
    )

    File.write!(path, content)

    IO.puts("Remaining active_state_set():")
    System.cmd("grep", ["-n", "active_state_set()", path], into: IO.stream(:stdio, :line))
    IO.puts("Remaining terminal_state_set():")
    System.cmd("grep", ["-n", "terminal_state_set()", path], into: IO.stream(:stdio, :line))
  end
end

FixOrchestrator2.run()
