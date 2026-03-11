defmodule FixOrchestrator do
  def run do
    path = "lib/symphony_elixir/orchestrator.ex"

    # Run git restore to clean up
    System.cmd("git", ["restore", path])

    content = File.read!(path)

    # 1. Update Struct
    content = String.replace(
      content,
      "codex_totals: nil,\n      codex_rate_limits: nil\n    ]",
      "codex_totals: nil,\n      codex_rate_limits: nil,\n      active_state_set: MapSet.new(),\n      terminal_state_set: MapSet.new()\n    ]"
    )

    # 2. Update init/1
    content = String.replace(
      content,
      "codex_totals: @empty_codex_totals,\n      codex_rate_limits: nil\n    }",
      "codex_totals: @empty_codex_totals,\n      codex_rate_limits: nil,\n      active_state_set: active_state_set(),\n      terminal_state_set: terminal_state_set()\n    }"
    )

    # 3. Update refresh_runtime_config/1
    content = String.replace(
      content,
      "poll_interval_ms: Config.poll_interval_ms(),\n        max_concurrent_agents: Config.max_concurrent_agents()\n    }",
      "poll_interval_ms: Config.poll_interval_ms(),\n        max_concurrent_agents: Config.max_concurrent_agents(),\n        active_state_set: active_state_set(),\n        terminal_state_set: terminal_state_set()\n    }"
    )

    # 4. Refactor call sites
    # Tracker.fetch_issues(active_state_set(), terminal_state_set())
    content = String.replace(
      content,
      "Tracker.fetch_issues(\n              active_state_set(),\n              terminal_state_set()\n            )",
      "Tracker.fetch_issues(\n              state.active_state_set,\n              state.terminal_state_set\n            )"
    )

    # reconcile_running_issue_states
    content = String.replace(
      content,
      "reconcile_running_issue_states(issues, state, active_state_set(), terminal_state_set())",
      "reconcile_running_issue_states(issues, state, state.active_state_set, state.terminal_state_set)"
    )

    # should_dispatch_issue?
    content = String.replace(
      content,
      "should_dispatch_issue?(issue, state, active_state_set(), terminal_state_set())",
      "should_dispatch_issue?(issue, state, state.active_state_set, state.terminal_state_set)"
    )

    # handle_cast dispatch_continuation
    content = String.replace(
      content,
      "active_states = active_state_set()\n      terminal_states = terminal_state_set()",
      "active_states = state.active_state_set\n      terminal_states = state.terminal_state_set"
    )

    # dispatch_issue
    content = String.replace(
      content,
      "revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, terminal_state_set())",
      "revalidate_issue_for_dispatch(issue, &Tracker.fetch_issue_states_by_ids/1, state.terminal_state_set)"
    )

    # handle_info handle_terminal_running_issues_result
    content = String.replace(
      content,
      "Logger.warning(\"Failed to refresh terminal running issues: \#{inspect(failures)}\")\n        terminal_states = terminal_state_set()",
      "Logger.warning(\"Failed to refresh terminal running issues: \#{inspect(failures)}\")\n        terminal_states = state.terminal_state_set"
    )

    # retry_candidate_issue inside handle_issue_fetch_results
    content = String.replace(
      content,
      "if retry_candidate_issue?(issue, terminal_state_set()) and",
      "if retry_candidate_issue?(issue, acc_state.active_state_set, acc_state.terminal_state_set) and"
    )

    # retry_candidate_issue? definition
    content = String.replace(
      content,
      "defp retry_candidate_issue?(%Issue{} = issue, terminal_states) do\n    candidate_issue?(issue, active_state_set(), terminal_states) and",
      "defp retry_candidate_issue?(%Issue{} = issue, active_states, terminal_states) do\n    candidate_issue?(issue, active_states, terminal_states) and"
    )

    File.write!(path, content)

    # Print the remaining occurrences of active_state_set() and terminal_state_set()
    IO.puts("Remaining active_state_set():")
    System.cmd("grep", ["-n", "active_state_set()", path], into: IO.stream(:stdio, :line))
    IO.puts("Remaining terminal_state_set():")
    System.cmd("grep", ["-n", "terminal_state_set()", path], into: IO.stream(:stdio, :line))
  end
end

FixOrchestrator.run()
