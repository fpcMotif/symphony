1. **Create `SymphonyElixir.Orchestrator.StateStore`**
   - Create `elixir/lib/symphony_elixir/orchestrator/state_store.ex` that saves and loads the state using Erlang terms and `File.read/write`.
   - Use `run_in_bash_session` to run `cat elixir/lib/symphony_elixir/orchestrator/state_store.ex` to verify the new file contents.

2. **Update Config module for data directory**
   - Edit `elixir/lib/symphony_elixir/config.ex` to define `def data_dir()` that returns `.symphony_data` in the workspace root.
   - Use `run_in_bash_session` to run `cat elixir/lib/symphony_elixir/config.ex` to verify the edit.

3. **Update `SymphonyElixir.Orchestrator` to load and save state**
   - Edit `elixir/lib/symphony_elixir/orchestrator.ex` to call `StateStore.load()` in `init/1` and merge state elements (`retry_attempts`, `claimed`, `completed`, `codex_totals`).
   - Add a private function `save_state(state)` that calls `StateStore.save(state)`.
   - Update all `handle_info` clauses to call `save_state(state)` right before returning `{:noreply, state}`.
   - Use `run_in_bash_session` to run `cat elixir/lib/symphony_elixir/orchestrator.ex` to verify the edits.

4. **Run Elixir tests**
   - I will use `run_in_bash_session` with Elixir and Mix to run the tests to verify the changes didn't break anything. (If mix isn't installed, I'll install it or run what I can).

5. **Complete pre commit steps**
   - Complete pre commit steps to make sure proper testing, verifications, reviews and reflections are done.

6. **Submit changes**
   - Create a branch and submit changes.
