defmodule Measure do
  alias SymphonyElixir.Orchestrator
  alias SymphonyElixir.Config

  defp normalize_issue_state(state_name) when is_binary(state_name) do
    String.downcase(String.trim(state_name))
  end

  def terminal_state_set do
    Config.linear_terminal_states()
    |> Enum.map(&normalize_issue_state/1)
    |> Enum.filter(&(&1 != ""))
    |> MapSet.new()
  end

  def run do
    # Warmup
    for _ <- 1..10, do: terminal_state_set()

    cached_set = terminal_state_set()

    # Dynamic computation
    {time_dynamic, _} = :timer.tc(fn ->
      for _ <- 1..10000 do
        terminal_state_set()
      end
    end)

    # Cached
    {time_cached, _} = :timer.tc(fn ->
      for _ <- 1..10000 do
        cached_set
      end
    end)

    IO.puts("Dynamic 10000 calls: #{time_dynamic} microsec")
    IO.puts("Cached 10000 calls: #{time_cached} microsec")
    IO.puts("Speedup: #{Float.round(time_dynamic / time_cached, 2)}x")
  end
end

Measure.run()
