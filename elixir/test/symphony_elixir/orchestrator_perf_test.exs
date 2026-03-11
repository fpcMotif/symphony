defmodule SymphonyElixir.OrchestratorPerfTest do
  use ExUnit.Case

  alias SymphonyElixir.Orchestrator
  alias SymphonyElixir.Linear.Issue
  alias SymphonyElixir.Orchestrator.State

  test "measure running_issue_count_for_state" do
    # create 10,000 running issues
    running_issues = Map.new(1..10000, fn i ->
      state_name = if rem(i, 2) == 0, do: "In Progress", else: "Todo"
      {
        "issue-#{i}",
        %{issue: %Issue{id: "issue-#{i}", state: state_name}}
      }
    end)

    # test checking 1000 candidate issues
    candidate_issues = Enum.map(1..1000, fn i ->
      %Issue{id: "cand-#{i}", state: "In Progress", priority: 1}
    end)

    state = %State{
      running: running_issues,
      claimed: MapSet.new(),
      max_concurrent_agents: 10000 # to allow dispatch check to proceed
    }

    # Run it 5 times to get an average
    # Use choose_issues_for_test to measure the fully optimized loop
    times = Enum.map(1..5, fn _ ->
      {time, _} = :timer.tc(fn ->
        Orchestrator.choose_issues_for_test(candidate_issues, state)
      end)
      time
    end)

    avg_time = Enum.sum(times) / length(times)
    IO.puts("\n\nOPTIMIZED FULL CHOOSE ISSUES AVG TIME: #{avg_time} microseconds\n\n")
  end
end
