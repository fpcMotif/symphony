path = "test/support/test_support.ex"
# Check if test_support creates %State{} with missing active_states and terminal_states
# Or we just fix should_dispatch_issue_for_test to pass the defaults if they are empty mapsets?
# Wait, should_dispatch_issue_for_test is defined as taking active_states and terminal_states from the state.
# But in test, we might initialize state with %State{} where active_states = MapSet.new() instead of actual defaults.
# Let's see how state is initialized in core_test.exs
