defmodule SymphonyElixir.Codex.DynamicToolEdgeTest do
  use SymphonyElixir.TestSupport

  alias SymphonyElixir.Codex.DynamicTool

  test "linear_graphql rejects invalid argument containers" do
    response = DynamicTool.execute("linear_graphql", :not_a_payload)

    assert response["success"] == false

    assert [item] = response["contentItems"]

    assert Jason.decode!(item["text"]) == %{
             "error" => %{
               "message" => "`linear_graphql` expects either a GraphQL query string or an object with `query` and optional `variables`."
             }
           }
  end

  test "linear_graphql rejects non-object variables" do
    response =
      DynamicTool.execute("linear_graphql", %{
        "query" => "query Viewer { viewer { id } }",
        "variables" => "invalid"
      })

    assert response["success"] == false
    assert [item] = response["contentItems"]

    assert Jason.decode!(item["text"]) == %{
             "error" => %{
               "message" => "`linear_graphql.variables` must be a JSON object when provided."
             }
           }
  end

  test "linear_graphql maps request transport errors into response payload" do
    response =
      DynamicTool.execute(
        "linear_graphql",
        %{"query" => "query Viewer { viewer { id } }"},
        linear_client: fn _query, _vars, _opts ->
          {:error, {:linear_api_request, :timeout}}
        end
      )

    assert response["success"] == false
    assert [item] = response["contentItems"]

    assert Jason.decode!(item["text"]) == %{
             "error" => %{
               "message" => "Linear GraphQL request failed before receiving a successful response.",
               "reason" => ":timeout"
             }
           }
  end
end
