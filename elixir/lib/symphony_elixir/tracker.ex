defmodule SymphonyElixir.Tracker do
  @moduledoc """
  Adapter boundary for issue tracker reads and writes.
  """

  alias SymphonyElixir.Config

  @callback fetch_candidate_issues() :: {:ok, [term()]} | {:error, term()}
  @callback fetch_issues_by_states([String.t()]) :: {:ok, [term()]} | {:error, term()}
  @callback fetch_issue_states_by_ids([String.t()]) :: {:ok, [term()]} | {:error, term()}
  @callback create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  @callback update_issue_state(String.t(), String.t()) :: :ok | {:error, term()}

  @spec fetch_candidate_issues() :: {:ok, [term()]} | {:error, term()}
  def fetch_candidate_issues do
    adapter = adapter()
    normalize_list_response(adapter.fetch_candidate_issues(), :fetch_candidate_issues)
  end

  @spec fetch_issues_by_states([String.t()]) :: {:ok, [term()]} | {:error, term()}
  def fetch_issues_by_states(states) do
    with {:ok, normalized_states} <- normalize_string_list(states, :invalid_states) do
      adapter = adapter()
      normalize_list_response(adapter.fetch_issues_by_states(normalized_states), :fetch_issues_by_states)
    end
  end

  @spec fetch_issue_states_by_ids([String.t()]) :: {:ok, [term()]} | {:error, term()}
  def fetch_issue_states_by_ids(issue_ids) do
    with {:ok, normalized_ids} <- normalize_string_list(issue_ids, :invalid_issue_ids) do
      adapter = adapter()
      normalize_list_response(adapter.fetch_issue_states_by_ids(normalized_ids), :fetch_issue_states_by_ids)
    end
  end

  @spec create_comment(String.t(), String.t()) :: :ok | {:error, term()}
  def create_comment(issue_id, body) do
    with {:ok, normalized_issue_id} <- normalize_string(issue_id, :invalid_issue_id),
         {:ok, normalized_body} <- normalize_string(body, :invalid_comment_body) do
      adapter = adapter()
      normalize_write_response(adapter.create_comment(normalized_issue_id, normalized_body), :create_comment)
    end
  end

  @spec update_issue_state(String.t(), String.t()) :: :ok | {:error, term()}
  def update_issue_state(issue_id, state_name) do
    with {:ok, normalized_issue_id} <- normalize_string(issue_id, :invalid_issue_id),
         {:ok, normalized_state_name} <- normalize_string(state_name, :invalid_state_name) do
      adapter = adapter()

      normalize_write_response(
        adapter.update_issue_state(normalized_issue_id, normalized_state_name),
        :update_issue_state
      )
    end
  end

  @spec adapter() :: module()
  def adapter do
    settings = Config.settings!()

    Application.get_env(:symphony_elixir, :tracker_adapter_module) ||
      case settings.tracker.kind do
        "memory" -> SymphonyElixir.Tracker.Memory
        "custom" -> String.to_atom("Elixir." <> settings.tracker.adapter_module)
        _ -> SymphonyElixir.Linear.Adapter
      end
  end

  defp normalize_list_response({:ok, values}, _operation) when is_list(values), do: {:ok, values}
  defp normalize_list_response({:error, reason}, _operation), do: {:error, reason}

  defp normalize_list_response(_response, operation),
    do: {:error, {:invalid_adapter_response, operation}}

  defp normalize_write_response(:ok, _operation), do: :ok
  defp normalize_write_response({:error, reason}, _operation), do: {:error, reason}

  defp normalize_write_response(_response, operation),
    do: {:error, {:invalid_adapter_response, operation}}

  defp normalize_string_list(values, _error) when is_list(values) do
    normalized_values =
      values
      |> Enum.filter(&is_binary/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {:ok, normalized_values}
  end

  defp normalize_string_list(_values, error), do: {:error, error}

  defp normalize_string(value, error) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> {:error, error}
      normalized_value -> {:ok, normalized_value}
    end
  end

  defp normalize_string(_value, error), do: {:error, error}
end
