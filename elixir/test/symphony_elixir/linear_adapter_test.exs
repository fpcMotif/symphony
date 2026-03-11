defmodule SymphonyElixir.LinearAdapterTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Linear.Adapter

  defmodule FakeLinearClient do
    def graphql(query, variables) do
      calls = Process.get({__MODULE__, :graphql_calls}, [])
      Process.put({__MODULE__, :graphql_calls}, calls ++ [{query, variables}])
      send(self(), {:graphql_called, query, variables})

      case Process.get({__MODULE__, :graphql_results}, []) do
        [result | rest] ->
          Process.put({__MODULE__, :graphql_results}, rest)
          result

        [] ->
          Process.get({__MODULE__, :graphql_result})
      end
    end
  end

  setup do
    previous_client = Application.get_env(:symphony_elixir, :linear_client_module)
    Application.put_env(:symphony_elixir, :linear_client_module, FakeLinearClient)

    on_exit(fn ->
      if is_nil(previous_client) do
        Application.delete_env(:symphony_elixir, :linear_client_module)
      else
        Application.put_env(:symphony_elixir, :linear_client_module, previous_client)
      end

      Process.delete({FakeLinearClient, :graphql_result})
      Process.delete({FakeLinearClient, :graphql_results})
      Process.delete({FakeLinearClient, :graphql_calls})
    end)

    :ok
  end

  describe "create_comment/2" do
    test "returns :ok when commentCreate.success is true" do
      put_graphql_results([
        {:ok, %{"data" => %{"commentCreate" => %{"success" => true}}}}
      ])

      assert :ok = Adapter.create_comment("issue-1", "hello")
      assert_receive {:graphql_called, mutation, %{issueId: "issue-1", body: "hello"}}
      assert mutation =~ "commentCreate"
      assert graphql_calls() == [{mutation, %{issueId: "issue-1", body: "hello"}}]
    end

    test "returns {:error, :comment_create_failed} when commentCreate.success is false" do
      put_graphql_results([
        {:ok, %{"data" => %{"commentCreate" => %{"success" => false}}}}
      ])

      assert {:error, :comment_create_failed} = Adapter.create_comment("issue-1", "hello")
    end

    test "returns {:error, :comment_create_failed} for malformed response body" do
      put_graphql_results([
        {:ok, %{"data" => %{}}}
      ])

      assert {:error, :comment_create_failed} = Adapter.create_comment("issue-1", "hello")
    end

    test "propagates graphql error tuple" do
      put_graphql_results([{:error, :linear_unavailable}])

      assert {:error, :linear_unavailable} = Adapter.create_comment("issue-1", "hello")
    end
  end

  describe "update_issue_state/2" do
    test "returns :ok when lookup returns state id and issue update succeeds" do
      put_graphql_results([
        {:ok,
         %{
           "data" => %{
             "issue" => %{"team" => %{"states" => %{"nodes" => [%{"id" => "state-1"}]}}}
           }
         }},
        {:ok, %{"data" => %{"issueUpdate" => %{"success" => true}}}}
      ])

      assert :ok = Adapter.update_issue_state("issue-1", "Done")

      assert_receive {:graphql_called, lookup_query, %{issueId: "issue-1", stateName: "Done"}}
      assert lookup_query =~ "query SymphonyResolveStateId"

      assert_receive {:graphql_called, update_mutation, %{issueId: "issue-1", stateId: "state-1"}}
      assert update_mutation =~ "mutation SymphonyUpdateIssueState"

      assert graphql_calls() == [
               {lookup_query, %{issueId: "issue-1", stateName: "Done"}},
               {update_mutation, %{issueId: "issue-1", stateId: "state-1"}}
             ]
    end

    test "returns {:error, :state_not_found} when lookup finds no state id" do
      put_graphql_results([
        {:ok, %{"data" => %{"issue" => %{"team" => %{"states" => %{"nodes" => []}}}}}}
      ])

      assert {:error, :state_not_found} = Adapter.update_issue_state("issue-1", "Missing")
    end

    test "returns {:error, :issue_update_failed} when update success is false" do
      put_graphql_results([
        {:ok,
         %{
           "data" => %{
             "issue" => %{"team" => %{"states" => %{"nodes" => [%{"id" => "state-1"}]}}}
           }
         }},
        {:ok, %{"data" => %{"issueUpdate" => %{"success" => false}}}}
      ])

      assert {:error, :issue_update_failed} = Adapter.update_issue_state("issue-1", "Done")
    end

    test "propagates graphql errors from state lookup" do
      put_graphql_results([{:error, :lookup_failed}])

      assert {:error, :lookup_failed} = Adapter.update_issue_state("issue-1", "Done")
    end

    test "propagates graphql errors from issue update" do
      put_graphql_results([
        {:ok,
         %{
           "data" => %{
             "issue" => %{"team" => %{"states" => %{"nodes" => [%{"id" => "state-1"}]}}}
           }
         }},
        {:error, :update_failed}
      ])

      assert {:error, :update_failed} = Adapter.update_issue_state("issue-1", "Done")
    end
  end

  defp put_graphql_results(results), do: Process.put({FakeLinearClient, :graphql_results}, results)

  defp graphql_calls, do: Process.get({FakeLinearClient, :graphql_calls}, [])
end
