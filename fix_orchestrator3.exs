defmodule FixOrchestrator3 do
  def run do
    path = "elixir/lib/symphony_elixir/orchestrator.ex"
    content = File.read!(path)

    # Revert init/1 and refresh_runtime_config/1 to use the function call instead of state.active_state_set
    content = String.replace(
      content,
      "      active_state_set: state.active_state_set,\n      terminal_state_set: state.terminal_state_set",
      "      active_state_set: active_state_set(),\n      terminal_state_set: terminal_state_set()"
    )

    File.write!(path, content)
  end
end

FixOrchestrator3.run()
