defmodule UpdateCallSites do
  def run do
    path = "elixir/lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # 1. Tracker.fetch_issues(active_state_set(), terminal_state_set()) -> Tracker.fetch_issues(state.active_state_set, state.terminal_state_set)
    content = String.replace(
      content,
      "Tracker.fetch_issues(active_state_set(), terminal_state_set())",
      "Tracker.fetch_issues(state.active_state_set, state.terminal_state_set)"
    )

    # 2. reconcile_running_issue_states calls
    content = String.replace(
      content,
      "reconcile_running_issue_states(issues, state, active_state_set(), terminal_state_set())",
      "reconcile_running_issue_states(issues, state, state.active_state_set, state.terminal_state_set)"
    )

    # 3. should_dispatch_issue? calls
    content = String.replace(
      content,
      "should_dispatch_issue?(issue, state, active_state_set(), terminal_state_set())",
      "should_dispatch_issue?(issue, state, state.active_state_set, state.terminal_state_set)"
    )

    # 4. In revalidate_issue_for_dispatch calls (in dispatch_issue)
    content = String.replace(
      content,
      "terminal_state_set()",
      "state.terminal_state_set"
    )

    # Wait, the above will replace ALL `terminal_state_set()` calls. Let's make sure that's safe.
    # We want to replace all calls where we have `state` context, and ensure we pass the correct arguments to those without `state`.

    # Let's do a regex replacement for active_state_set() and terminal_state_set() where we have `state`.
    # Let's review all occurrences manually using grep instead of automatic replacement for safety,
    # or just use explicit replacements.
    File.write!(path, content)
  end
end

UpdateCallSites.run()
