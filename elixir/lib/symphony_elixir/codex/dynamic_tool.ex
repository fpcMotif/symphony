defmodule SymphonyElixir.Codex.DynamicTool do
  @moduledoc """
  Executes client-side tool calls requested by Codex app-server turns.
  """

  alias SymphonyElixir.{Config, Linear.Client}

  @linear_graphql_tool "linear_graphql"
  @linear_graphql_description """
  Execute a raw GraphQL query or mutation against Linear using Symphony's configured auth.
  """
  @linear_graphql_input_schema %{
    "type" => "object",
    "additionalProperties" => false,
    "required" => ["query"],
    "properties" => %{
      "query" => %{
        "type" => "string",
        "description" => "GraphQL query or mutation document to execute against Linear."
      },
      "variables" => %{
        "type" => ["object", "null"],
        "description" => "Optional GraphQL variables object.",
        "additionalProperties" => true
      }
    }
  }

  @spec execute(String.t() | nil, term(), keyword()) :: map()
  def execute(tool, arguments, opts \\ []) do
    case tool do
      @linear_graphql_tool ->
        if linear_graphql_disabled?(opts) do
          unsupported_tool_response(tool, opts)
        else
          execute_linear_graphql(arguments, opts)
        end

      other ->
        unsupported_tool_response(other, opts)
    end
  end

  @spec tool_specs(keyword()) :: [map()]
  def tool_specs(opts \\ []) do
    if linear_graphql_advertised?(opts) do
      [
        %{
          "name" => @linear_graphql_tool,
          "description" => @linear_graphql_description,
          "inputSchema" => @linear_graphql_input_schema
        }
      ]
    else
      []
    end
  end

  defp execute_linear_graphql(arguments, opts) do
    linear_client = Keyword.get(opts, :linear_client, &Client.graphql/3)

    with {:ok, query, variables} <- normalize_linear_graphql_arguments(arguments),
         {:ok, response} <- linear_client.(query, variables, []) do
      graphql_response(response)
    else
      {:error, reason} ->
        failure_response(tool_error_payload(reason))
    end
  end

  defp normalize_linear_graphql_arguments(arguments) when is_binary(arguments) do
    with {:ok, query} <- normalize_query_string(arguments) do
      {:ok, query, %{}}
    end
  end

  defp normalize_linear_graphql_arguments(arguments) when is_map(arguments) do
    case normalize_query(arguments) do
      {:ok, query} ->
        case normalize_variables(arguments) do
          {:ok, variables} ->
            {:ok, query, variables}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_linear_graphql_arguments(_arguments), do: {:error, :invalid_arguments}

  defp normalize_query(arguments) do
    case Map.get(arguments, "query") || Map.get(arguments, :query) do
      query when is_binary(query) ->
        normalize_query_string(query)

      _ ->
        {:error, :missing_query}
    end
  end

  defp normalize_query_string(query) when is_binary(query) do
    case String.trim(query) do
      "" ->
        {:error, :missing_query}

      trimmed ->
        validate_single_graphql_operation(trimmed)
    end
  end

  defp normalize_variables(arguments) do
    case Map.get(arguments, "variables") || Map.get(arguments, :variables) || %{} do
      variables when is_map(variables) -> {:ok, variables}
      _ -> {:error, :invalid_variables}
    end
  end

  defp validate_single_graphql_operation(query) when is_binary(query) do
    operation_count =
      query
      |> sanitize_graphql_document()
      |> count_graphql_operations()

    if operation_count <= 1 do
      {:ok, query}
    else
      {:error, :multiple_operations}
    end
  end

  defp sanitize_graphql_document(query) when is_binary(query) do
    query
    |> then(&Regex.replace(~r/""".*?"""/s, &1, ""))
    |> then(&Regex.replace(~r/"(?:\\.|[^"\\])*"/s, &1, ""))
    |> then(&Regex.replace(~r/#.*$/m, &1, ""))
  end

  defp count_graphql_operations(query) when is_binary(query) do
    explicit_operations =
      Regex.scan(~r/(?:^\s*|}\s*)(?:query|mutation|subscription)\b/s, query)
      |> length()

    if explicit_operations > 0 do
      explicit_operations
    else
      if String.starts_with?(String.trim_leading(query), "{"), do: 1, else: 0
    end
  end

  defp graphql_response(response) do
    success =
      case response do
        %{"errors" => errors} when is_list(errors) and errors != [] -> false
        %{errors: errors} when is_list(errors) and errors != [] -> false
        _ -> true
      end

    %{
      "success" => success,
      "contentItems" => [
        %{
          "type" => "inputText",
          "text" => encode_payload(response)
        }
      ]
    }
  end

  defp failure_response(payload) do
    %{
      "success" => false,
      "contentItems" => [
        %{
          "type" => "inputText",
          "text" => encode_payload(payload)
        }
      ]
    }
  end

  defp unsupported_tool_response(tool, opts) do
    failure_response(%{
      "error" => %{
        "message" => "Unsupported dynamic tool: #{inspect(tool)}.",
        "supportedTools" => supported_tool_names(opts)
      }
    })
  end

  defp encode_payload(payload) when is_map(payload) or is_list(payload) do
    Jason.encode!(payload, pretty: true)
  end

  defp encode_payload(payload), do: inspect(payload)

  defp tool_error_payload(:missing_query) do
    %{
      "error" => %{
        "message" => "`linear_graphql` requires a non-empty `query` string."
      }
    }
  end

  defp tool_error_payload(:invalid_arguments) do
    %{
      "error" => %{
        "message" => "`linear_graphql` expects either a GraphQL query string or an object with `query` and optional `variables`."
      }
    }
  end

  defp tool_error_payload(:invalid_variables) do
    %{
      "error" => %{
        "message" => "`linear_graphql.variables` must be a JSON object when provided."
      }
    }
  end

  defp tool_error_payload(:multiple_operations) do
    %{
      "error" => %{
        "message" => "`linear_graphql.query` must contain exactly one GraphQL operation."
      }
    }
  end

  defp tool_error_payload(:missing_linear_api_token) do
    %{
      "error" => %{
        "message" => "Symphony is missing Linear auth. Set `linear.api_key` in `WORKFLOW.md` or export `LINEAR_API_KEY`."
      }
    }
  end

  defp tool_error_payload({:linear_api_status, status}) do
    %{
      "error" => %{
        "message" => "Linear GraphQL request failed with HTTP #{status}.",
        "status" => status
      }
    }
  end

  defp tool_error_payload({:linear_api_request, reason}) do
    %{
      "error" => %{
        "message" => "Linear GraphQL request failed before receiving a successful response.",
        "reason" => inspect(reason)
      }
    }
  end

  defp tool_error_payload(reason) do
    %{
      "error" => %{
        "message" => "Linear GraphQL tool execution failed.",
        "reason" => inspect(reason)
      }
    }
  end

  defp linear_graphql_disabled?(opts) when is_list(opts) do
    case Keyword.fetch(opts, :linear_graphql_enabled) do
      {:ok, value} -> value == false
      :error -> not Config.codex_linear_graphql_enabled?()
    end
  end

  defp linear_graphql_advertised?(opts) when is_list(opts) do
    case Keyword.fetch(opts, :linear_graphql_enabled) do
      {:ok, value} -> value == true and linear_graphql_configured?()
      :error -> Config.codex_linear_graphql_enabled?() and linear_graphql_configured?()
    end
  end

  defp linear_graphql_configured? do
    Config.tracker_kind() == "linear" and is_binary(Config.linear_api_token())
  end

  defp supported_tool_names(opts) do
    Enum.map(tool_specs(opts), & &1["name"])
  end
end
