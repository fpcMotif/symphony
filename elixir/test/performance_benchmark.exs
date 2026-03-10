defmodule PerformanceBenchmark do
  alias SymphonyElixir.Config

  # Simulation of current logic
  def normalize_issue_state(state_name) when is_binary(state_name) do
    String.downcase(String.trim(state_name))
  end

  def terminal_state_set do
    Config.linear_terminal_states()
    |> Enum.map(&normalize_issue_state/1)
    |> Enum.filter(&(&1 != ""))
    |> MapSet.new()
  end

  def active_state_set do
    Config.linear_active_states()
    |> Enum.map(&normalize_issue_state/1)
    |> Enum.filter(&(&1 != ""))
    |> MapSet.new()
  end

  def run do
    # Benchee benchmark
    Benchee.run(%{
      "uncached_terminal_state_set" => fn _ -> terminal_state_set() end,
      "uncached_active_state_set" => fn _ -> active_state_set() end,
      "cached_terminal_state_set" => fn state -> state.terminal_state_set end,
      "cached_active_state_set" => fn state -> state.active_state_set end
    },
    before_scenario: fn _ ->
      %{
        terminal_state_set: terminal_state_set(),
        active_state_set: active_state_set()
      }
    end,
    time: 2,
    memory_time: 2
    )
  end
end

PerformanceBenchmark.run()
