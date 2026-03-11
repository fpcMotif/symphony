defmodule SymphonyElixir.Orchestrator.StateStore do
  @moduledoc """
  Manages persistence of Orchestrator state (retry queue and session metadata)
  across process restarts.
  """

  require Logger
  alias SymphonyElixir.Config

  @state_file "orchestrator_state.erl"

  def load do
    file_path = state_file_path()

    case File.read(file_path) do
      {:ok, binary} ->
        try do
          state = :erlang.binary_to_term(binary)
          {:ok, state}
        rescue
          e ->
            Logger.warning("Failed to parse saved orchestrator state: #{inspect(e)}")
            :error
        end

      {:error, :enoent} ->
        :error

      {:error, reason} ->
        Logger.warning("Failed to read saved orchestrator state: #{inspect(reason)}")
        :error
    end
  end

  def save(state) do
    file_path = state_file_path()

    # We only want to persist certain fields
    persistable_state = %{
      retry_attempts: state.retry_attempts,
      claimed: state.claimed,
      completed: state.completed,
      codex_totals: state.codex_totals
    }

    try do
      binary = :erlang.term_to_binary(persistable_state)
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, binary)
      :ok
    rescue
      e ->
        Logger.warning("Failed to save orchestrator state: #{inspect(e)}")
        {:error, e}
    end
  end

  defp state_file_path do
    Path.join([Config.data_dir(), @state_file])
  end
end
