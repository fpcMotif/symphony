# We should update the State struct to initialize active_states and terminal_states properly.
# We can just change defstruct in Orchestrator.State to have defaults? MapSet is not allowed in module attributes, but we can do it in a macro or simply we just populate it in tests if needed.
# Since we can't use MapSet.new() as a struct default value unless we use macro or it's evaluated at compile time. Wait, `defstruct` does allow MapSet.new() as default if it's evaluated at compile-time. But wait, in elixir `defstruct [completed: MapSet.new()]` is evaluated once at compile time!
# But for active_states: active_state_set(), it reads from config. So if it reads from config at compile time, it might get the test config or empty. That's why I didn't put it in `defstruct` and put it in `init/1`.
# Let's fix test instances of %Orchestrator.State{} to include active_states and terminal_states, OR we can add a helper `Orchestrator.State.new()` to initialize it.
