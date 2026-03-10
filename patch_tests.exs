path = "lib/symphony_elixir/orchestrator.ex"
content = File.read!(path)

content = String.replace(
  content,
  "def reconcile_issue_states_for_test(issues, %State{} = state) when is_list(issues) do\n    reconcile_running_issue_states(issues, state, state.active_states, state.terminal_states)\n  end",
  "def reconcile_issue_states_for_test(issues, %State{} = state) when is_list(issues) do\n    active = if Enum.empty?(state.active_states), do: active_state_set(), else: state.active_states\n    terminals = if Enum.empty?(state.terminal_states), do: terminal_state_set(), else: state.terminal_states\n    reconcile_running_issue_states(issues, state, active, terminals)\n  end"
)
content = String.replace(
  content,
  "def reconcile_issue_states_for_test(issues, state) when is_list(issues) do\n    reconcile_running_issue_states(issues, state, state.active_states, state.terminal_states)\n  end",
  "def reconcile_issue_states_for_test(issues, state) when is_list(issues) do\n    active = if Enum.empty?(state.active_states), do: active_state_set(), else: state.active_states\n    terminals = if Enum.empty?(state.terminal_states), do: terminal_state_set(), else: state.terminal_states\n    reconcile_running_issue_states(issues, state, active, terminals)\n  end"
)

content = String.replace(
  content,
  "def should_dispatch_issue_for_test(%Issue{} = issue, %State{} = state) do\n    should_dispatch_issue?(issue, state, state.active_states, state.terminal_states)\n  end",
  "def should_dispatch_issue_for_test(%Issue{} = issue, %State{} = state) do\n    active = if Enum.empty?(state.active_states), do: active_state_set(), else: state.active_states\n    terminals = if Enum.empty?(state.terminal_states), do: terminal_state_set(), else: state.terminal_states\n    should_dispatch_issue?(issue, state, active, terminals)\n  end"
)

File.write!(path, content)
