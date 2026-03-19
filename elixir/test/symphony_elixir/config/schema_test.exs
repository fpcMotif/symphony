defmodule SymphonyElixir.Config.SchemaTest do
  use ExUnit.Case, async: true
  alias SymphonyElixir.Config.Schema

  test "linear_graphql_enabled is normalized properly" do
    config_true = %{
      "codex" => %{
        "linear_graphql_enabled" => "  tRuE   "
      }
    }

    config_false = %{
      "codex" => %{
        "linear_graphql_enabled" => "  FaLsE   "
      }
    }

    config_drop = %{
      "codex" => %{
        "linear_graphql_enabled" => "what"
      }
    }

    assert {:ok, result_true} = Schema.parse(config_true)
    assert result_true.codex.linear_graphql_enabled == true

    assert {:ok, result_false} = Schema.parse(config_false)
    assert result_false.codex.linear_graphql_enabled == false

    assert {:ok, result_drop} = Schema.parse(config_drop)
    assert result_drop.codex.linear_graphql_enabled == true
  end

  test "linear_graphql_enabled is dropped if invalid type" do
    config_invalid = %{
      "codex" => %{
        "linear_graphql_enabled" => 123
      }
    }

    assert {:ok, result_invalid} = Schema.parse(config_invalid)
    assert result_invalid.codex.linear_graphql_enabled == true
  end
end
