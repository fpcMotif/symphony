defmodule SymphonyElixir.PerfTest do
  def run do
    # setup dummy candidates
    candidates = for i <- 1..50, do: %{id: "id-#{i}", state: "todo", identifier: "ID-#{i}"}
    state = %{}

    IO.puts "Starting tests..."

    # test current code flow
    {time, _} = :timer.tc(fn ->
      Enum.reduce(candidates, state, fn issue, state_acc ->
         # pretend fetch single issue
         fetch_single = fn ids ->
             Process.sleep(10) # fake latency
             {:ok, [Map.put(issue, :state, "todo")]}
         end

         case fetch_single.([issue.id]) do
             {:ok, [refreshed_issue | _]} -> state_acc
             _ -> state_acc
         end
      end)
    end)
    IO.puts "Sequential (Current Flow): #{time / 1_000.0}ms"


    {time, _} = :timer.tc(fn ->
       candidate_ids = Enum.map(candidates, & &1.id)

       # Fetch all at once
       fetch_batch = fn ids ->
          Process.sleep(10)
          {:ok, Enum.map(ids, fn id -> Enum.find(candidates, &(&1.id == id)) end)}
       end

       case fetch_batch.(candidate_ids) do
         {:ok, refreshed_issues} ->
             refreshed_issues_map = Map.new(refreshed_issues, &{&1.id, &1})

             Enum.reduce(candidates, state, fn issue, state_acc ->
                 case Map.fetch(refreshed_issues_map, issue.id) do
                   {:ok, refreshed_issue} -> state_acc
                   :error -> state_acc
                 end
             end)
         _ -> state
       end
    end)
    IO.puts "Batching (Proposed Flow): #{time / 1_000.0}ms"

  end
end
SymphonyElixir.PerfTest.run()
