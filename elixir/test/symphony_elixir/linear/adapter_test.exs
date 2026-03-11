defmodule SymphonyElixir.Linear.AdapterTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Linear.Adapter

  setup do
    previous = Application.get_env(:symphony_elixir, :linear_client_module)
    Application.put_env(:symphony_elixir, :linear_client_module, __MODULE__.MockClient)

    on_exit(fn ->
      if previous do
        Application.put_env(:symphony_elixir, :linear_client_module, previous)
      else
        Application.delete_env(:symphony_elixir, :linear_client_module)
      end
    end)

    :ok
  end

  describe "create_comment/2" do
    test "returns :ok when comment creation succeeds" do
      set_mock_graphql_response(fn _query, _vars ->
        {:ok, %{"data" => %{"commentCreate" => %{"success" => true}}}}
      end)

      assert :ok = Adapter.create_comment("issue-1", "Test comment")
    end

    test "returns error when comment creation returns success=false" do
      set_mock_graphql_response(fn _query, _vars ->
        {:ok, %{"data" => %{"commentCreate" => %{"success" => false}}}}
      end)

      assert {:error, :comment_create_failed} = Adapter.create_comment("issue-1", "Test comment")
    end

    test "returns error when graphql call fails" do
      set_mock_graphql_response(fn _query, _vars ->
        {:error, :network_error}
      end)

      assert {:error, :network_error} = Adapter.create_comment("issue-1", "Test comment")
    end
  end

  describe "update_issue_state/2" do
    test "returns :ok when state lookup and update both succeed" do
      set_mock_graphql_response(fn _query, vars ->
        cond do
          Map.has_key?(vars, :stateName) ->
            {:ok,
             %{
               "data" => %{
                 "issue" => %{
                   "team" => %{
                     "states" => %{
                       "nodes" => [%{"id" => "state-done-id"}]
                     }
                   }
                 }
               }
             }}

          Map.has_key?(vars, :stateId) ->
            {:ok, %{"data" => %{"issueUpdate" => %{"success" => true}}}}

          true ->
            {:error, :unexpected_query}
        end
      end)

      assert :ok = Adapter.update_issue_state("issue-1", "Done")
    end

    test "returns error when state lookup finds no matching state" do
      set_mock_graphql_response(fn _query, _vars ->
        {:ok,
         %{
           "data" => %{
             "issue" => %{
               "team" => %{
                 "states" => %{
                   "nodes" => []
                 }
               }
             }
           }
         }}
      end)

      assert {:error, :state_not_found} = Adapter.update_issue_state("issue-1", "Nonexistent")
    end

    test "returns error when state lookup graphql call fails" do
      set_mock_graphql_response(fn _query, _vars ->
        {:error, :timeout}
      end)

      assert {:error, :timeout} = Adapter.update_issue_state("issue-1", "Done")
    end

    test "returns error when update mutation returns success=false" do
      set_mock_graphql_response(fn _query, vars ->
        if Map.has_key?(vars, :stateName) do
          {:ok,
           %{
             "data" => %{
               "issue" => %{
                 "team" => %{
                   "states" => %{
                     "nodes" => [%{"id" => "state-done-id"}]
                   }
                 }
               }
             }
           }}
        else
          {:ok, %{"data" => %{"issueUpdate" => %{"success" => false}}}}
        end
      end)

      assert {:error, :issue_update_failed} = Adapter.update_issue_state("issue-1", "Done")
    end
  end

  describe "delegation" do
    test "fetch_candidate_issues delegates to client module" do
      set_mock_fetch(:fetch_candidate_issues, fn -> {:ok, [%Issue{id: "i1"}]} end)
      assert {:ok, [%Issue{id: "i1"}]} = Adapter.fetch_candidate_issues()
    end

    test "fetch_issues_by_states delegates to client module" do
      set_mock_fetch(:fetch_issues_by_states, fn _states -> {:ok, []} end)
      assert {:ok, []} = Adapter.fetch_issues_by_states(["Todo"])
    end

    test "fetch_issue_states_by_ids delegates to client module" do
      set_mock_fetch(:fetch_issue_states_by_ids, fn _ids -> {:ok, []} end)
      assert {:ok, []} = Adapter.fetch_issue_states_by_ids(["id-1"])
    end
  end

  # --- Mock client module ---

  defmodule MockClient do
    def graphql(query, variables, _opts \\ []) do
      case Process.get(:mock_graphql_response) do
        nil -> {:error, :no_mock_configured}
        fun when is_function(fun, 2) -> fun.(query, variables)
      end
    end

    def fetch_candidate_issues do
      case Process.get(:mock_fetch_candidate_issues) do
        nil -> {:ok, []}
        fun -> fun.()
      end
    end

    def fetch_issues_by_states(states) do
      case Process.get(:mock_fetch_issues_by_states) do
        nil -> {:ok, []}
        fun -> fun.(states)
      end
    end

    def fetch_issue_states_by_ids(ids) do
      case Process.get(:mock_fetch_issue_states_by_ids) do
        nil -> {:ok, []}
        fun -> fun.(ids)
      end
    end
  end

  defp set_mock_graphql_response(fun) when is_function(fun, 2) do
    Process.put(:mock_graphql_response, fun)
  end

  defp set_mock_fetch(function_name, fun) do
    Process.put(:"mock_#{function_name}", fun)
  end
end
